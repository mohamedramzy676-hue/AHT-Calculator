import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AhtHistoryStorage {
  static const _key = 'aht_monthly_history_v1';

  static Future<Map<String, List<Map<String, int>>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((month, value) => MapEntry(
          month,
          (value as List)
              .map((item) => Map<String, int>.from(item as Map))
              .toList(),
        ));
  }

  static Future<void> save(Map<String, List<Map<String, int>>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }
}
