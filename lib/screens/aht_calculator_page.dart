import 'package:flutter/material.dart';
import '../core/aht_calculator.dart';

class AhtCalculatorPage extends StatefulWidget {
  const AhtCalculatorPage({super.key, this.targetSeconds = 430});
  final int targetSeconds;

  @override
  State<AhtCalculatorPage> createState() => _AhtCalculatorPageState();
}

class _AhtCalculatorPageState extends State<AhtCalculatorPage> {
  final List<int> durations = [];

  int roundedAverage(List<int> values) => AhtCalculator.average(values).round();

  String clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  int? get previousAht {
    if (durations.length < 2) return null;
    return roundedAverage(durations.sublist(0, durations.length - 1));
  }

  Future<void> addDuration() async {
    final min = TextEditingController();
    final sec = TextEditingController();
    String? error;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add call duration'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: min, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: sec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds'))),
          ]),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final minutes = int.tryParse(min.text);
            final seconds = int.tryParse(sec.text);
            if (minutes == null || seconds == null || minutes < 0 || seconds < 0 || seconds > 59 || minutes * 60 + seconds <= 0) {
              setDialogState(() => error = 'Enter a valid time. Seconds must be 0–59.');
              return;
            }
            Navigator.pop(context, minutes * 60 + seconds);
          }, child: const Text('Add Call')),
        ],
      )),
    );
    if (value != null) setState(() => durations.add(value));
  }

  @override
  Widget build(BuildContext context) {
    final hasCalls = durations.isNotEmpty;
    final aht = hasCalls ? roundedAverage(durations) : 0;
    final targetDifference = hasCalls ? aht - widget.targetSeconds : 0;
    final previous = previousAht;
    final lastChange = previous == null ? null : aht - previous;
    final total = AhtCalculator.totalSeconds(durations);

    String targetStatus() {
      if (!hasCalls) return 'Add a call to start calculating.';
      if (targetDifference == 0) return 'Exactly on target';
      if (targetDifference < 0) return '${targetDifference.abs()} sec below target';
      return '+$targetDifference sec above target';
    }

    String changeStatus() {
      if (lastChange == null) return 'Add another call to see how much your AHT changes.';
      if (lastChange == 0) return 'Last call did not change your AHT.';
      if (lastChange < 0) return 'Last call improved AHT by ${lastChange.abs()} sec ↓';
      return 'Last call increased AHT by $lastChange sec ↑';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AHT Calculator')),
      floatingActionButton: FloatingActionButton.extended(onPressed: addDuration, icon: const Icon(Icons.add_call), label: const Text('Add Call')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          const Text('CURRENT AHT', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(hasCalls ? '$aht sec' : '--', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold)),
          if (hasCalls) Text('${clock(aht)} min:sec', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Text('Target ${widget.targetSeconds} sec (${clock(widget.targetSeconds)})', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(targetStatus(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: !hasCalls ? null : targetDifference <= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error)),
        ]))),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: Icon(lastChange != null && lastChange <= 0 ? Icons.trending_down : Icons.trending_up),
          title: const Text('Change after last call', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(changeStatus()),
        )),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(label: 'Calls', value: '${durations.length}')),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'Total seconds', value: '$total')),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: addDuration, icon: const Icon(Icons.add), label: const Text('Add duration'))),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: durations.isEmpty ? null : () => setState(durations.clear), child: const Text('Clear')),
        ]),
        const SizedBox(height: 24),
        const Text('Call durations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (durations.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Enter calls in minutes and seconds. Each call will also be shown in total seconds.')))
        else
          ...durations.asMap().entries.map((entry) {
            final running = roundedAverage(durations.take(entry.key + 1).toList());
            final before = entry.key == 0 ? null : roundedAverage(durations.take(entry.key).toList());
            final delta = before == null ? null : running - before;
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text('${entry.value} sec  •  ${clock(entry.value)}'),
              subtitle: Text('AHT after call: $running sec${delta == null ? '' : delta == 0 ? ' • no change' : delta < 0 ? ' • ${delta.abs()} sec lower ↓' : ' • $delta sec higher ↑'}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => durations.removeAt(entry.key))),
            ));
          }),
        const SizedBox(height: 90),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text(label)])));
}
