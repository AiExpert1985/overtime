import 'dart:convert';

import '../database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _db;

  SettingsRepository(this._db);

  Future<String> getString(String key, {required String defaultValue}) async {
    final db = await _db.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return defaultValue;
    return rows.first['value'] as String;
  }

  Future<int> getInt(String key, {required int defaultValue}) async {
    final raw = await getString(key, defaultValue: defaultValue.toString());
    return int.tryParse(raw) ?? defaultValue;
  }

  Future<void> setValue(String key, String value) async {
    final db = await _db.database;
    await db.execute(
      'INSERT INTO app_settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  Future<List<String>> getShiftStartTimes() async {
    final raw = await getString('shift_start_times', defaultValue: '["08:00","11:00"]');
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.cast<String>();
    return ['08:00', '11:00'];
  }

  Future<void> setShiftStartTimes(List<String> times) async {
    await setValue('shift_start_times', jsonEncode(times));
  }
}
