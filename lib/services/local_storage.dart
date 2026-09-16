import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _callsKey = 'calls_seconds';
  static const _targetKey = 'target_seconds';
  static const _remainingKey = 'expected_remaining_calls';
  static const _monthCallsKey = 'month_calls';
  static const _monthSecondsKey = 'month_seconds';
  static const _monthRemainingKey = 'month_remaining_calls';

  static Future<void> save({
    required List<int> calls,
    required int targetSeconds,
    required int expectedRemainingCalls,
    required int monthCalls,
    required int monthSeconds,
    required int monthRemainingCalls,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_callsKey, calls.map((e) => e.toString()).toList());
    await prefs.setInt(_targetKey, targetSeconds);
    await prefs.setInt(_remainingKey, expectedRemainingCalls);
    await prefs.setInt(_monthCallsKey, monthCalls);
    await prefs.setInt(_monthSecondsKey, monthSeconds);
    await prefs.setInt(_monthRemainingKey, monthRemainingCalls);
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'calls': (prefs.getStringList(_callsKey) ?? []).map(int.parse).toList(),
      'targetSeconds': prefs.getInt(_targetKey) ?? 430,
      'expectedRemainingCalls': prefs.getInt(_remainingKey) ?? 20,
      'monthCalls': prefs.getInt(_monthCallsKey) ?? 0,
      'monthSeconds': prefs.getInt(_monthSecondsKey) ?? 0,
      'monthRemainingCalls': prefs.getInt(_monthRemainingKey) ?? 0,
    };
  }
}
