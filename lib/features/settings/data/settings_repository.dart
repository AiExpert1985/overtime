import 'package:sqflite/sqflite.dart';

import '../domain/app_settings.dart';
import '../domain/column_header.dart';

class SettingsRepository {
  const SettingsRepository(this._db);

  final Database _db;

  Future<AppSettings> loadSettings() async {
    final rows = await _db.query('app_settings');
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return AppSettings.fromMap(map);
  }

  Future<void> updateSetting(String key, String value) async {
    await _db.update(
      'app_settings',
      {'value': value},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<Map<String, List<ColumnHeader>>> loadColumnHeaders() async {
    final rows = await _db.query(
      'column_headers',
      where: 'file_type = ?',
      whereArgs: ['attendance'],
      orderBy: 'is_default DESC, id ASC',
    );
    final result = <String, List<ColumnHeader>>{};
    for (final row in rows) {
      final h = ColumnHeader.fromMap(row);
      result.putIfAbsent(h.fieldKey, () => []).add(h);
    }
    return result;
  }

  Future<void> addColumnHeader(String fieldKey, String headerValue) async {
    await _db.insert('column_headers', {
      'file_type': 'attendance',
      'field_key': fieldKey,
      'header_value': headerValue,
      'is_default': 0,
    });
  }

  Future<void> updateColumnHeader(int id, String headerValue) async {
    await _db.update(
      'column_headers',
      {'header_value': headerValue},
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  Future<void> deleteColumnHeader(int id) async {
    await _db.delete(
      'column_headers',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }
}
