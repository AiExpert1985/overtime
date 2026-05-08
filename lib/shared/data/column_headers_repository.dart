import '../database/database_helper.dart';

class ColumnHeaderItem {
  final int id;
  final String fileType;
  final String fieldKey;
  final String headerValue;
  final bool isDefault;

  const ColumnHeaderItem({
    required this.id,
    required this.fileType,
    required this.fieldKey,
    required this.headerValue,
    required this.isDefault,
  });
}

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

  Future<Map<String, Map<String, List<ColumnHeaderItem>>>> getAllHeaders() async {
    final db = await _db.database;
    final rows = await db.query('column_headers', orderBy: 'file_type, field_key, is_default DESC, id ASC');

    final Map<String, Map<String, List<ColumnHeaderItem>>> result = {};
    for (final row in rows) {
      final fileType = row['file_type'] as String;
      final fieldKey = row['field_key'] as String;
      final item = ColumnHeaderItem(
        id: row['id'] as int,
        fileType: fileType,
        fieldKey: fieldKey,
        headerValue: row['header_value'] as String,
        isDefault: (row['is_default'] as int) == 1,
      );
      result.putIfAbsent(fileType, () => {}).putIfAbsent(fieldKey, () => []).add(item);
    }
    return result;
  }

  Future<bool> headerValueExists(
    String fileType,
    String fieldKey,
    String value, {
    int? excludeId,
  }) async {
    final db = await _db.database;
    final where = excludeId != null
        ? 'file_type = ? AND field_key = ? AND header_value = ? AND id != ?'
        : 'file_type = ? AND field_key = ? AND header_value = ?';
    final args = excludeId != null
        ? [fileType, fieldKey, value, excludeId]
        : [fileType, fieldKey, value];
    final rows = await db.query(
      'column_headers',
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addHeader(String fileType, String fieldKey, String headerValue) async {
    final db = await _db.database;
    await db.insert('column_headers', {
      'file_type': fileType,
      'field_key': fieldKey,
      'header_value': headerValue,
      'is_default': 0,
    });
  }

  Future<void> updateHeader(int id, String newValue) async {
    final db = await _db.database;
    await db.update(
      'column_headers',
      {'header_value': newValue},
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  Future<void> deleteHeader(int id) async {
    final db = await _db.database;
    await db.delete(
      'column_headers',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }
}
