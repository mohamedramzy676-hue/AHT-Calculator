import 'package:flutter/material.dart';
import '../services/aht_history_storage.dart';

class AhtCalculatorPage extends StatefulWidget {
  const AhtCalculatorPage({super.key, this.targetSeconds = 430});
  final int targetSeconds;

  @override
  State<AhtCalculatorPage> createState() => _AhtCalculatorPageState();
}

class _AhtCalculatorPageState extends State<AhtCalculatorPage> {
  static const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  Map<String, List<Map<String, int>>> history = {};
  late int selectedMonth;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now().month - 1;
    _load();
  }

  String get monthKey => '${DateTime.now().year}-${(selectedMonth + 1).toString().padLeft(2, '0')}';
  List<Map<String, int>> get calls => history[monthKey] ?? const [];
  int callTotal(Map<String, int> c) => (c['talk'] ?? 0) + (c['hold'] ?? 0) + (c['acw'] ?? 0);
  int get totalHandling => calls.fold(0, (sum, c) => sum + callTotal(c));
  int get aht => calls.isEmpty ? 0 : (totalHandling / calls.length).round();
  String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> _load() async {
    history = await AhtHistoryStorage.load();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() => AhtHistoryStorage.save(history);

  Future<int?> _timeDialog(String title, int initial) async {
    final min = TextEditingController(text: initial == 0 ? '' : '${initial ~/ 60}');
    final sec = TextEditingController(text: initial == 0 ? '' : '${initial % 60}');
    String? error;
    return showDialog<int>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: TextField(controller: min, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds'))),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final m = int.tryParse(min.text.isEmpty ? '0' : min.text);
          final s = int.tryParse(sec.text.isEmpty ? '0' : sec.text);
          if (m == null || s == null || m < 0 || s < 0 || s > 59) { setLocal(() => error = 'Seconds must be between 0 and 59.'); return; }
          Navigator.pop(context, m * 60 + s);
        }, child: const Text('Save')),
      ],
    )));
  }

  Future<void> editCall({int? index}) async {
    final old = index == null ? <String, int>{'talk':0,'hold':0,'acw':0} : Map<String, int>.from(calls[index]);
    int talk = old['talk'] ?? 0, hold = old['hold'] ?? 0, acw = old['acw'] ?? 0;
    final result = await showDialog<Map<String, int>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: Text(index == null ? 'Add Call' : 'Edit Call ${index + 1}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _TimeRow(label: 'Talk time', seconds: talk, onTap: () async { final v = await _timeDialog('Talk time', talk); if (v != null) setLocal(() => talk = v); }),
        _TimeRow(label: 'Hold / waiting', seconds: hold, onTap: () async { final v = await _timeDialog('Hold / waiting time', hold); if (v != null) setLocal(() => hold = v); }),
        _TimeRow(label: 'After call work', seconds: acw, onTap: () async { final v = await _timeDialog('After call work time', acw); if (v != null) setLocal(() => acw = v); }),
        const Divider(),
        ListTile(title: const Text('Handling time', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${talk + hold + acw} sec', style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: talk + hold + acw <= 0 ? null : () => Navigator.pop(context, {'talk':talk,'hold':hold,'acw':acw}), child: const Text('Save Call')),
      ],
    )));
    if (result == null) return;
    final list = List<Map<String, int>>.from(calls);
    if (index == null) { list.add(result); } else { list[index] = result; }
    setState(() => history[monthKey] = list);
    await _save();
  }

  Future<void> deleteCall(int index) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete call?'), content: Text('Call ${index + 1} will be removed from ${months[selectedMonth]}.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (yes != true) return;
    final list = List<Map<String, int>>.from(calls)..removeAt(index);
    setState(() => history[monthKey] = list);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final diff = aht - widget.targetSeconds;
    final achieved = calls.isNotEmpty && aht <= widget.targetSeconds;
    return Scaffold(
      appBar: AppBar(title: const Text('AHT Tracker')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => editCall(), icon: const Icon(Icons.add_call), label: const Text('Add Call')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SizedBox(height: 48, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: months.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, i) => ChoiceChip(label: Text(months[i]), selected: selectedMonth == i, onSelected: (_) => setState(() => selectedMonth = i)))),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Text('${months[selectedMonth]} ${DateTime.now().year}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(calls.isEmpty ? '--' : '$aht sec', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold)),
          if (calls.isNotEmpty) Text('${clock(aht)} • ${calls.length} received calls'),
          const SizedBox(height: 10),
          Text('Target ${widget.targetSeconds} sec (${clock(widget.targetSeconds)})'),
          const SizedBox(height: 8),
          if (calls.isNotEmpty) Text(achieved ? 'Target achieved • ${diff.abs()} sec below target' : '$diff sec above target', style: TextStyle(fontWeight: FontWeight.bold, color: achieved ? Colors.green.shade700 : Theme.of(context).colorScheme.error)),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('AHT = (Total Talk Time + Total Hold/Waiting Time + Total After Call Work) ÷ Number of Received Calls', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)))),
        const SizedBox(height: 20),
        Text('Calls • ${months[selectedMonth]}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (calls.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No calls in this month yet. Add a call and enter Talk, Hold and After Call Work time.'))) else
          ...calls.asMap().entries.map((entry) {
            final c = entry.value;
            final seconds = callTotal(c);
            final runningCalls = calls.take(entry.key + 1).toList();
            final runningTotal = runningCalls.fold(0, (sum, item) => sum + callTotal(item));
            final runningAht = (runningTotal / runningCalls.length).round();
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text('$seconds sec  •  ${clock(seconds)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Talk ${c['talk']}s • Hold ${c['hold']}s • ACW ${c['acw']}s\nAHT after call: $runningAht sec'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') editCall(index: entry.key); if (value == 'delete') deleteCall(entry.key); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined), SizedBox(width: 8), Text('Edit')])), PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline), SizedBox(width: 8), Text('Delete')]))]),
            ));
          }),
        const SizedBox(height: 90),
      ]),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.seconds, required this.onTap});
  final String label;
  final int seconds;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, title: Text(label), subtitle: Text('$seconds sec'), trailing: TextButton(onPressed: onTap, child: Text(seconds == 0 ? 'Enter' : 'Edit')));
}
