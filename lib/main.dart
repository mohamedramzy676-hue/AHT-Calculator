import 'package:flutter/material.dart';
import 'screens/aht_dashboard_page.dart';

void main() => runApp(const AhtPulseApp());

class AhtPulseApp extends StatelessWidget {
  const AhtPulseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AHT Pulse',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2878E5)),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 1,
            margin: EdgeInsets.zero,
          ),
        ),
        home: const AhtDashboardPage(),
      );
}
