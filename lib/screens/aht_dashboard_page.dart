import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallEntry {
  CallEntry({
    required this.talk,
    required this.hold,
    required this.acw,
  });

  int talk;
  int hold;
  int acw;

  int get total => talk + hold + acw;

  Map<String, dynamic> toJson() => {
        'talk': talk,
        'hold': hold,
        'acw': acw,
      };

  factory CallEntry.fromJson(Map<String, dynamic> json) {
    return CallEntry(
      talk: json['talk'] ?? 0,
      hold: json['hold'] ?? 0,
      acw: json['acw'] ?? 0,
    );
  }
}

class AhtDashboardPage extends StatefulWidget {
  const AhtDashboardPage({super.key});

  @override
  State<AhtDashboardPage> createState() => _AhtDashboardPageState();
}

class _AhtDashboardPageState extends State<AhtDashboardPage> {
  static const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  int selectedMonth = DateTime.now().month - 1;
  int target = 430;
  bool loading = true;

  final Map<int, List<CallEntry>> data = {};

  final TextEditingController quickMinutes = TextEditingController();
  final TextEditingController quickSeconds = TextEditingController();

  final FocusNode quickMinutesFocus = FocusNode();
  final FocusNode quickSecondsFocus = FocusNode();

  List<CallEntry> get calls {
    return data.putIfAbsent(selectedMonth, () => []);
  }

  int get totalSeconds {
    return calls.fold<int>(0, (sum, call) => sum + call.total);
  }

  int get aht {
    if (calls.isEmpty) return 0;
    return (totalSeconds / calls.length).round();
  }

  int? get lastChange {
    if (calls.length < 2) return null;

    final previousTotal = calls
        .take(calls.length - 1)
        .fold<int>(0, (sum, call) => sum + call.total);

    final previousAht = (previousTotal / (calls.length - 1)).round();

    return aht - previousAht;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    quickMinutes.dispose();
    quickSeconds.dispose();
    quickMinutesFocus.dispose();
    quickSecondsFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    target = prefs.getInt('target_seconds') ?? 430;

    for (var month = 0; month < 12; month++) {
      final raw = prefs.getString('aht_month_$month');

      if (raw != null) {
        final decoded = jsonDecode(raw) as List;

        data[month] = decoded
            .map(
              (item) => CallEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        quickMinutesFocus.requestFocus();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('target_seconds', target);

    await prefs.setString(
      'aht_month_$selectedMonth',
      jsonEncode(
        calls.map((call) => call.toJson()).toList(),
      ),
    );
  }

  String mmss(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> quickAdd() async {
    final minutes = int.tryParse(quickMinutes.text.trim()) ?? 0;
    final seconds = int.tryParse(quickSeconds.text.trim()) ?? 0;

    if (minutes < 0 ||
        seconds < 0 ||
        seconds > 59 ||
        (minutes == 0 && seconds == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid minutes and seconds.',
          ),
        ),
      );
      return;
    }

    final totalCallSeconds = (minutes * 60) + seconds;

    setState(() {
      calls.add(
        CallEntry(
          talk: totalCallSeconds,
          hold: 0,
          acw: 0,
        ),
      );
    });

    quickMinutes.clear();
    quickSeconds.clear();

    await _save();

    if (mounted) {
      quickMinutesFocus.requestFocus();
    }
  }

  void moveToSeconds(String value) {
    if (value.length >= 2) {
      quickSecondsFocus.requestFocus();
    }
  }

  Future<List<int>?> _detailsDialog(
    String title, [
    CallEntry? entry,
  ]) async {
    final values = [
      entry?.talk ?? 0,
      entry?.hold ?? 0,
      entry?.acw ?? 0,
    ];

    final controllers = List.generate(
      6,
      (index) {
        final value = values[index ~/ 2];

        if (index.isEven) {
          final minutes = value ~/ 60;

          return TextEditingController(
            text: minutes > 0 ? '$minutes' : '',
          );
        }

        final seconds = value % 60;

        return TextEditingController(
          text: seconds > 0 ? '$seconds' : '',
        );
      },
    );

    return showDialog<List<int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 620,
            child: Row(
              children: List.generate(
                3,
                (index) {
                  final labels = [
                    'Talk Time',
                    'Hold / Waiting',
                    'After Call Work',
                  ];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels[index],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controllers[index * 2],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Min',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  ':',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: controllers[index * 2 + 1],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                      2,
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Sec',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final result = <int>[];

                for (var index = 0; index < 3; index++) {
                  final minutes = int.tryParse(
                        controllers[index * 2].text,
                      ) ??
                      0;

                  final seconds = int.tryParse(
                        controllers[index * 2 + 1].text,
                      ) ??
                      0;

                  if (minutes < 0 || seconds < 0 || seconds > 59) {
                    return;
                  }

                  result.add(
                    (minutes * 60) + seconds,
                  );
                }

                if (result.reduce((a, b) => a + b) > 0) {
                  Navigator.pop(context, result);
                }
              },
              child: Text(
                entry == null ? 'Add Call' : 'Save Changes',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> addDetailed() async {
    final result = await _detailsDialog('Add Call Details');

    if (result != null) {
      setState(() {
        calls.add(
          CallEntry(
            talk: result[0],
            hold: result[1],
            acw: result[2],
          ),
        );
      });

      await _save();

      if (mounted) {
        quickMinutesFocus.requestFocus();
      }
    }
  }

  Future<void> editCall(int index) async {
    final result = await _detailsDialog(
      'Edit Call',
      calls[index],
    );

    if (result != null) {
      setState(() {
        calls[index] = CallEntry(
          talk: result[0],
          hold: result[1],
          acw: result[2],
        );
      });

      await _save();
    }
  }

  Future<void> deleteCall(int index) async {
    setState(() {
      calls.removeAt(index);
    });

    await _save();

    if (mounted) {
      quickMinutesFocus.requestFocus();
    }
  }

  Future<void> clearAll() async {
    setState(() {
      calls.clear();
    });

    await _save();

    if (mounted) {
      quickMinutesFocus.requestFocus();
    }
  }

  Future<void> editTarget() async {
    final controller = TextEditingController(text: '$target');

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('AHT Target'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Target in seconds',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);

                if (value != null && value > 0) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        target = result;
      });

      await _save();
    }
  }

  Widget stat(
    String title,
    String value,
    String subtitle,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget quickTimeInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.bolt,
              color: Colors.amber,
              size: 30,
            ),
            const SizedBox(width: 10),
            const Text(
              'Quick Call Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 110,
              child: TextField(
                controller: quickMinutes,
                focusNode: quickMinutesFocus,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onChanged: moveToSeconds,
                onSubmitted: (_) {
                  quickSecondsFocus.requestFocus();
                },
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  hintText: '6',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: quickSeconds,
                focusNode: quickSecondsFocus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onSubmitted: (_) {
                  quickAdd();
                },
                decoration: const InputDecoration(
                  labelText: 'Seconds',
                  hintText: '30',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: quickAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: addDetailed,
              icon: const Icon(Icons.tune),
              label: const Text('Add Hold / ACW'),
            ),
            const Spacer(),
            const Text(
              'Enter call time and press Enter',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final difference = aht - target;
    final change = lastChange;

    return Scaffold(
      backgroundColor: const Color(0xfff5f8fc),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xff172b42),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.blueAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AHT Pulse',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: editTarget,
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Target $target sec (${mmss(target)})',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(7),
                children: List.generate(
                  12,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    child: ChoiceChip(
                      label: Text(months[index]),
                      selected: selectedMonth == index,
                      onSelected: (_) {
                        setState(() {
                          selectedMonth = index;
                        });

                        quickMinutes.clear();
                        quickSeconds.clear();

                        quickMinutesFocus.requestFocus();
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                6,
                18,
                10,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.count(
                    crossAxisCount: constraints.maxWidth > 900 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: constraints.maxWidth > 900 ? 2.7 : 1.9,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      stat(
                        'Current AHT',
                        calls.isEmpty ? '--' : '$aht sec',
                        calls.isEmpty
                            ? 'No calls'
                            : '${mmss(aht)} • ${difference <= 0 ? 'Target met' : '${difference.abs()} sec above target'}',
                        Icons.bar_chart,
                        color: calls.isEmpty
                            ? null
                            : difference <= 0
                                ? Colors.green
                                : Colors.red,
                      ),
                      stat(
                        'Target',
                        '$target sec',
                        mmss(target),
                        Icons.track_changes,
                      ),
                      stat(
                        'Last Call Change',
                        change == null
                            ? '--'
                            : '${change > 0 ? '+' : ''}$change sec',
                        change == null
                            ? 'Add more calls'
                            : change <= 0
                                ? 'AHT improved'
                                : 'AHT increased',
                        change != null && change <= 0
                            ? Icons.trending_down
                            : Icons.trending_up,
                        color: change == null
                            ? null
                            : change <= 0
                                ? Colors.green
                                : Colors.red,
                      ),
                      stat(
                        'Total Calls',
                        '${calls.length}',
                        '$totalSeconds total seconds',
                        Icons.phone,
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1450,
                    ),
                    child: Column(
                      children: [
                        quickTimeInput(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              '${monthNames[selectedMonth]} ${DateTime.now().year}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (calls.isNotEmpty)
                              TextButton.icon(
                                onPressed: clearAll,
                                icon: const Icon(
                                  Icons.delete_sweep,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Clear month',
                                  style: TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (calls.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                32,
                              ),
                              child: Center(
                                child: Text(
                                  'No calls yet. Enter minutes and seconds above.',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ),
                          )
                        else
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                10,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(
                                      label: Text('#'),
                                    ),
                                    DataColumn(
                                      label: Text('Call Time'),
                                    ),
                                    DataColumn(
                                      label: Text('Hold'),
                                    ),
                                    DataColumn(
                                      label: Text('ACW'),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Total (Sec)',
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text('AHT MTD'),
                                    ),
                                    DataColumn(
                                      label: Text('Change'),
                                    ),
                                    DataColumn(
                                      label: Text('Actions'),
                                    ),
                                  ],
                                  rows: List.generate(
                                    calls.length,
                                    (index) {
                                      final call = calls[index];

                                      final runningTotal = calls
                                          .take(
                                            index + 1,
                                          )
                                          .fold<int>(
                                            0,
                                            (
                                              sum,
                                              item,
                                            ) =>
                                                sum + item.total,
                                          );

                                      final runningAht =
                                          (runningTotal / (index + 1)).round();

                                      int? previousAht;

                                      if (index > 0) {
                                        final previousTotal = calls
                                            .take(
                                              index,
                                            )
                                            .fold<int>(
                                              0,
                                              (
                                                sum,
                                                item,
                                              ) =>
                                                  sum + item.total,
                                            );

                                        previousAht =
                                            (previousTotal / index).round();
                                      }

                                      final rowChange = previousAht == null
                                          ? null
                                          : runningAht - previousAht;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              '${index + 1}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              mmss(
                                                call.talk,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              mmss(
                                                call.hold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              mmss(
                                                call.acw,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${call.total}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '$runningAht sec',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              rowChange == null
                                                  ? '-'
                                                  : '${rowChange > 0 ? '+' : ''}$rowChange ${rowChange > 0 ? '↑' : rowChange < 0 ? '↓' : ''}',
                                              style: TextStyle(
                                                color: rowChange == null
                                                    ? null
                                                    : rowChange <= 0
                                                        ? Colors.green
                                                        : Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () {
                                                    editCall(
                                                      index,
                                                    );
                                                  },
                                                  tooltip: 'Edit',
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    deleteCall(
                                                      index,
                                                    );
                                                  },
                                                  tooltip: 'Delete',
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(
                              18,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Monthly Summary • ${calls.length} calls • $totalSeconds sec • ${calls.isEmpty ? 'No AHT yet' : 'AHT MTD $aht sec (${mmss(aht)})'}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (calls.isNotEmpty)
                                  Chip(
                                    label: Text(
                                      difference <= 0
                                          ? 'TARGET MET'
                                          : 'TARGET NOT MET',
                                    ),
                                    backgroundColor: difference <= 0
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
