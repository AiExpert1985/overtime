import '../database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _db;

  SettingsRepository(this._db);

  Future<int> getInt(String key, {required int defaultValue}) async {
    final db = await _db.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return defaultValue;
    return int.tryParse(rows.first['value'] as String) ?? defaultValue;
  }
}
