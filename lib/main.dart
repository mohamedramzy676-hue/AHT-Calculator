import 'package:flutter/material.dart';

void main() => runApp(const AhtPulseApp());

class AhtPulseApp extends StatelessWidget {
  const AhtPulseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AHT Pulse',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5FEF)), useMaterial3: true),
        home: const DashboardPage(),
      );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int targetSeconds = 430;
  int expectedRemainingCalls = 20;
  final List<int> calls = [];

  int get totalSeconds => calls.fold(0, (sum, value) => sum + value);
  double get currentAht => calls.isEmpty ? 0 : totalSeconds / calls.length;

  double? get requiredRemainingAht {
    if (calls.isEmpty || expectedRemainingCalls <= 0) return null;
    return (targetSeconds * (calls.length + expectedRemainingCalls) - totalSeconds) / expectedRemainingCalls;
  }

  String formatSeconds(num value) {
    if (value < 0) return 'Impossible';
    final seconds = value.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> addCall() async {
    final min = TextEditingController();
    final sec = TextEditingController();
    final duration = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add handling time'),
        content: Row(children: [
          Expanded(child: TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final value = ((int.tryParse(min.text) ?? 0) * 60) + (int.tryParse(sec.text) ?? 0);
            Navigator.pop(context, value > 0 ? value : null);
          }, child: const Text('Save Call')),
        ],
      ),
    );
    if (duration != null) setState(() => calls.add(duration));
  }

  Future<void> editPlan() async {
    final targetMin = TextEditingController(text: '${targetSeconds ~/ 60}');
    final targetSec = TextEditingController(text: '${targetSeconds % 60}');
    final remaining = TextEditingController(text: '$expectedRemainingCalls');
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily target plan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Target AHT')),
          Row(children: [
            Expanded(child: TextField(controller: targetMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: targetSec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds'))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: remaining, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected remaining calls')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final target = ((int.tryParse(targetMin.text) ?? 0) * 60) + (int.tryParse(targetSec.text) ?? 0);
            final callsLeft = int.tryParse(remaining.text) ?? 0;
            if (target > 0 && callsLeft >= 0) Navigator.pop(context, [target, callsLeft]);
          }, child: const Text('Save Plan')),
        ],
      ),
    );
    if (result != null) setState(() { targetSeconds = result[0]; expectedRemainingCalls = result[1]; });
  }

  @override
  Widget build(BuildContext context) {
    final onTarget = calls.isNotEmpty && currentAht <= targetSeconds;
    final rescue = requiredRemainingAht;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AHT Pulse', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: editPlan, tooltip: 'Edit target', icon: const Icon(Icons.tune))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: addCall, icon: const Icon(Icons.add_call), label: const Text('Add Call')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Today', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(calls.isEmpty ? 'Log your first call to start tracking.' : onTarget ? 'You are currently on target.' : 'Your AHT is above target. Use the rescue plan below.'),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          const Text('CURRENT AHT'),
          const SizedBox(height: 8),
          Text(calls.isEmpty ? '--:--' : formatSeconds(currentAht), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold)),
          Text('Target ${formatSeconds(targetSeconds)}'),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MetricCard(label: 'Calls', value: '${calls.length}', icon: Icons.call)),
          const SizedBox(width: 12),
          Expanded(child: _MetricCard(label: 'Handling', value: formatSeconds(totalSeconds), icon: Icons.timer_outlined)),
        ]),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Target Rescue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(onPressed: editPlan, icon: const Icon(Icons.edit_outlined)),
          ]),
          Text('$expectedRemainingCalls expected calls remaining'),
          const SizedBox(height: 12),
          Text(rescue == null ? 'Add a call to calculate your required pace.' : rescue < 0 ? 'This target cannot be reached with the selected remaining calls.' : 'Average ${formatSeconds(rescue)} or less on the next $expectedRemainingCalls calls to finish at ${formatSeconds(targetSeconds)}.', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ]))),
        const SizedBox(height: 20),
        Text('Recent calls', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (calls.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No calls logged yet.'))) else ...calls.reversed.take(5).map((seconds) => Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.call)),
          title: Text('Handling time ${formatSeconds(seconds)}'),
          subtitle: Text(seconds <= targetSeconds ? 'At or below target' : 'Above target'),
        ))),
        const SizedBox(height: 90),
      ])),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon), const SizedBox(height: 18), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text(label),
  ])));
}
