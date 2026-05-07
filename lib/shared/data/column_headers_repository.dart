import '../database/database_helper.dart';

class ColumnHeadersRepository {
  final DatabaseHelper _db;

  ColumnHeadersRepository(this._db);

  Future<Map<String, List<String>>> getHeadersForFileType(String fileType) async {
    final db = await _db.database;
    final rows = await db.query(
      'column_headers',
      columns: ['field_key', 'header_value'],
      where: 'file_type = ?',
      whereArgs: [fileType],
    );

    final Map<String, List<String>> result = {};
    for (final row in rows) {
      final key = row['field_key'] as String;
      final value = row['header_value'] as String;
      result.putIfAbsent(key, () => []).add(value);
    }
    return result;
  }
}
