import 'package:flutter/material.dart';

void main() => runApp(const AhtPulseApp());

class AhtPulseApp extends StatelessWidget {
  const AhtPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AHT Pulse',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5FEF)),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int targetSeconds = 430;
  final List<int> calls = [];

  int get totalSeconds => calls.fold(0, (sum, seconds) => sum + seconds);
  double get currentAht => calls.isEmpty ? 0 : totalSeconds / calls.length;

  String formatSeconds(num value) {
    final seconds = value.round();
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  Future<void> addCall() async {
    final minutesController = TextEditingController();
    final secondsController = TextEditingController();

    final duration = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add handling time'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: secondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seconds'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(minutesController.text) ?? 0;
              final seconds = int.tryParse(secondsController.text) ?? 0;
              final total = (minutes * 60) + seconds;
              Navigator.pop(context, total > 0 ? total : null);
            },
            child: const Text('Save Call'),
          ),
        ],
      ),
    );

    if (duration != null) setState(() => calls.add(duration));
  }

  @override
  Widget build(BuildContext context) {
    final onTarget = calls.isNotEmpty && currentAht <= targetSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AHT Pulse', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Target ${formatSeconds(targetSeconds)}')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCall,
        icon: const Icon(Icons.add_call),
        label: const Text('Add Call'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Today', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              calls.isEmpty ? 'Log your first call to start tracking.' : onTarget ? 'You are currently on target.' : 'Your AHT is currently above target.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('CURRENT AHT'),
                    const SizedBox(height: 8),
                    Text(
                      calls.isEmpty ? '--:--' : formatSeconds(currentAht),
                      style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold),
                    ),
                    Text('Target ${formatSeconds(targetSeconds)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _MetricCard(label: 'Calls', value: '${calls.length}', icon: Icons.call)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(label: 'Handling', value: formatSeconds(totalSeconds), icon: Icons.timer_outlined)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Recent calls', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (calls.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No calls logged yet.')))
            else
              ...calls.reversed.take(5).map(
                    (seconds) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.call)),
                        title: Text('Handling time ${formatSeconds(seconds)}'),
                        subtitle: Text(seconds <= targetSeconds ? 'At or below target' : 'Above target'),
                      ),
                    ),
                  ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 18),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}
