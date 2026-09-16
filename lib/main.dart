import 'package:flutter/material.dart';
import 'screens/aht_calculator_page.dart';
import 'services/local_storage.dart';

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
  int monthCalls = 0;
  int monthSeconds = 0;
  int monthRemainingCalls = 0;
  List<int> calls = [];
  bool loading = true;

  int get totalSeconds => calls.fold(0, (sum, value) => sum + value);
  double get currentAht => calls.isEmpty ? 0 : totalSeconds / calls.length;
  double get monthAht => monthCalls == 0 ? 0 : monthSeconds / monthCalls;
  double? get requiredRemainingAht => calls.isEmpty || expectedRemainingCalls <= 0 ? null : (targetSeconds * (calls.length + expectedRemainingCalls) - totalSeconds) / expectedRemainingCalls;
  double? get requiredMonthAht => monthCalls <= 0 || monthRemainingCalls <= 0 ? null : (targetSeconds * (monthCalls + monthRemainingCalls) - monthSeconds) / monthRemainingCalls;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await LocalStorage.load();
    if (!mounted) return;
    setState(() {
      calls = List<int>.from(data['calls']);
      targetSeconds = data['targetSeconds'];
      expectedRemainingCalls = data['expectedRemainingCalls'];
      monthCalls = data['monthCalls'];
      monthSeconds = data['monthSeconds'];
      monthRemainingCalls = data['monthRemainingCalls'];
      loading = false;
    });
  }

  Future<void> _save() => LocalStorage.save(calls: calls, targetSeconds: targetSeconds, expectedRemainingCalls: expectedRemainingCalls, monthCalls: monthCalls, monthSeconds: monthSeconds, monthRemainingCalls: monthRemainingCalls);

  String formatSeconds(num value) {
    if (value < 0) return 'Impossible';
    final seconds = value.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> addCall() async {
    final min = TextEditingController();
    final sec = TextEditingController();
    final duration = await showDialog<int>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add handling time'),
      content: Row(children: [Expanded(child: TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes'))), const SizedBox(width: 12), Expanded(child: TextField(controller: sec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds')))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final m = int.tryParse(min.text) ?? 0; final s = int.tryParse(sec.text) ?? 0; final value = m * 60 + s; if (m >= 0 && s >= 0 && s < 60 && value > 0) Navigator.pop(context, value); }, child: const Text('Save Call'))],
    ));
    if (duration != null) { setState(() { calls.add(duration); monthCalls++; monthSeconds += duration; }); await _save(); }
  }

  Future<void> editPlan() async {
    final targetMin = TextEditingController(text: '${targetSeconds ~/ 60}');
    final targetSec = TextEditingController(text: '${targetSeconds % 60}');
    final remaining = TextEditingController(text: '$expectedRemainingCalls');
    final result = await showDialog<List<int>>(context: context, builder: (context) => AlertDialog(
      title: const Text('Daily target plan'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [Expanded(child: TextField(controller: targetMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target minutes'))), const SizedBox(width: 12), Expanded(child: TextField(controller: targetSec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds')))]), const SizedBox(height: 12), TextField(controller: remaining, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected remaining calls'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final target = ((int.tryParse(targetMin.text) ?? 0) * 60) + (int.tryParse(targetSec.text) ?? 0); final left = int.tryParse(remaining.text) ?? 0; if (target > 0 && left >= 0) Navigator.pop(context, [target, left]); }, child: const Text('Save Plan'))],
    ));
    if (result != null) { setState(() { targetSeconds = result[0]; expectedRemainingCalls = result[1]; }); await _save(); }
  }

  Future<void> editMonth() async {
    final count = TextEditingController(text: '$monthCalls');
    final ahtMin = TextEditingController(text: monthCalls == 0 ? '' : '${monthAht.floor() ~/ 60}');
    final ahtSec = TextEditingController(text: monthCalls == 0 ? '' : '${monthAht.round() % 60}');
    final remaining = TextEditingController(text: '$monthRemainingCalls');
    final result = await showDialog<List<int>>(context: context, builder: (context) => AlertDialog(
      title: const Text('Monthly AHT plan'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calls handled this month')), const SizedBox(height: 12), Row(children: [Expanded(child: TextField(controller: ahtMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current AHT min'))), const SizedBox(width: 12), Expanded(child: TextField(controller: ahtSec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sec')))]), const SizedBox(height: 12), TextField(controller: remaining, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected remaining calls this month'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final c = int.tryParse(count.text) ?? 0; final avg = ((int.tryParse(ahtMin.text) ?? 0) * 60) + (int.tryParse(ahtSec.text) ?? 0); final left = int.tryParse(remaining.text) ?? 0; if (c >= 0 && avg >= 0 && left >= 0) Navigator.pop(context, [c, c * avg, left]); }, child: const Text('Save Month'))],
    ));
    if (result != null) { setState(() { monthCalls = result[0]; monthSeconds = result[1]; monthRemainingCalls = result[2]; }); await _save(); }
  }

  void openCalculator() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AhtCalculatorPage()));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final rescue = requiredRemainingAht;
    final monthlyRescue = requiredMonthAht;
    return Scaffold(
      appBar: AppBar(title: const Text('AHT Pulse', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: openCalculator, tooltip: 'AHT Calculator', icon: const Icon(Icons.calculate_outlined)), IconButton(onPressed: editPlan, tooltip: 'Target settings', icon: const Icon(Icons.tune))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: addCall, icon: const Icon(Icons.add_call), label: const Text('Add Call')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Today', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _AhtCard(title: 'CURRENT AHT', value: calls.isEmpty ? '--:--' : formatSeconds(currentAht), subtitle: 'Target ${formatSeconds(targetSeconds)}'),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _MetricCard(label: 'Calls', value: '${calls.length}', icon: Icons.call)), const SizedBox(width: 12), Expanded(child: _MetricCard(label: 'Handling', value: formatSeconds(totalSeconds), icon: Icons.timer_outlined))]),
        const SizedBox(height: 16),
        Card(child: ListTile(onTap: openCalculator, leading: const CircleAvatar(child: Icon(Icons.calculate_outlined)), title: const Text('Quick AHT Calculator', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Enter several call durations and instantly calculate their AHT.'), trailing: const Icon(Icons.chevron_right))),
        const SizedBox(height: 16),
        _PlanCard(title: 'Daily Target Rescue', subtitle: '$expectedRemainingCalls calls remaining', message: rescue == null ? 'Add calls and set remaining calls to calculate your pace.' : rescue < 0 ? 'Target cannot be reached with the selected number of calls.' : 'Keep the next $expectedRemainingCalls calls at ${formatSeconds(rescue)} AHT or less.', onEdit: editPlan),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('This Month', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), IconButton(onPressed: editMonth, icon: const Icon(Icons.edit_outlined))]),
        _AhtCard(title: 'MONTHLY AHT', value: monthCalls == 0 ? '--:--' : formatSeconds(monthAht), subtitle: '$monthCalls calls • Target ${formatSeconds(targetSeconds)}'),
        const SizedBox(height: 12),
        _PlanCard(title: 'Monthly Rescue', subtitle: '$monthRemainingCalls expected calls remaining', message: monthlyRescue == null ? 'Enter your current monthly calls, AHT and expected remaining calls.' : monthlyRescue < 0 ? 'Monthly target cannot be reached with the selected remaining calls.' : 'Average ${formatSeconds(monthlyRescue)} or less across the next $monthRemainingCalls calls to finish at ${formatSeconds(targetSeconds)}.', onEdit: editMonth),
        const SizedBox(height: 28),
        Text('Recent calls', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        if (calls.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No calls logged yet.'))) else ...calls.reversed.take(5).map((s) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.call)), title: Text('Handling time ${formatSeconds(s)}'), subtitle: Text(s <= targetSeconds ? 'At or below target' : 'Above target')))),
        const SizedBox(height: 90),
      ])),
    );
  }
}

class _AhtCard extends StatelessWidget {
  const _AhtCard({required this.title, required this.value, required this.subtitle});
  final String title, value, subtitle;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Text(title), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)), Text(subtitle)])));
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.subtitle, required this.message, required this.onEdit});
  final String title, subtitle, message; final VoidCallback onEdit;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined))]), Text(subtitle), const SizedBox(height: 10), Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))])));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label, value; final IconData icon;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 18), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)), Text(label)])));
}
