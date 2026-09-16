import 'package:flutter/material.dart';
import '../core/aht_calculator.dart';

class AhtCalculatorPage extends StatefulWidget {
  const AhtCalculatorPage({super.key});

  @override
  State<AhtCalculatorPage> createState() => _AhtCalculatorPageState();
}

class _AhtCalculatorPageState extends State<AhtCalculatorPage> {
  final List<int> durations = [];

  String formatSeconds(num value) {
    final seconds = value.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> addDuration() async {
    final min = TextEditingController();
    final sec = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add call duration'),
        content: Row(children: [
          Expanded(child: TextField(controller: min, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final minutes = int.tryParse(min.text) ?? 0;
            final seconds = int.tryParse(sec.text) ?? 0;
            if (minutes >= 0 && seconds >= 0 && seconds < 60 && minutes * 60 + seconds > 0) {
              Navigator.pop(context, minutes * 60 + seconds);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
    if (value != null) setState(() => durations.add(value));
  }

  @override
  Widget build(BuildContext context) {
    final average = AhtCalculator.average(durations);
    final total = AhtCalculator.totalSeconds(durations);
    return Scaffold(
      appBar: AppBar(title: const Text('AHT Calculator')),
      floatingActionButton: FloatingActionButton.extended(onPressed: addDuration, icon: const Icon(Icons.add), label: const Text('Add Call')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          const Text('CALCULATED AHT'),
          const SizedBox(height: 8),
          Text(durations.isEmpty ? '--:--' : formatSeconds(average), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold)),
          Text('${durations.length} calls • Total ${formatSeconds(total)}'),
        ]))),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: addDuration, icon: const Icon(Icons.add_call), label: const Text('Add duration'))),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: durations.isEmpty ? null : () => setState(durations.clear), child: const Text('Clear')),
        ]),
        const SizedBox(height: 22),
        const Text('Call durations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (durations.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Add two or more calls and the calculator will instantly show their AHT.')))
        else
          ...durations.asMap().entries.map((entry) => Card(child: ListTile(
            leading: CircleAvatar(child: Text('${entry.key + 1}')),
            title: Text('Call ${entry.key + 1}'),
            subtitle: Text(formatSeconds(entry.value)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => durations.removeAt(entry.key))),
          ))),
        const SizedBox(height: 90),
      ]),
    );
  }
}
