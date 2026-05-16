import 'dart:io';

import 'package:excel/excel.dart';

import '../../settings/domain/column_header.dart';
import '../domain/employee_entry.dart';

class GenerationException implements Exception {
  GenerationException(this.arabicMessage);
  final String arabicMessage;
}

class GenerationService {
  static const _requiredKeys = ['employee_name', 'department', 'datetime'];

  // Stage 3 — Dictionary Build
  Future<Map<String, EmployeeEntry>> buildDictionary(
    List<String> validFilePaths,
    DateTime startDate,
    DateTime endDate,
    List<ColumnHeader> headers,
  ) async {
    final acceptable = _buildAcceptableMap(headers);
    final dictionary = <String, EmployeeEntry>{};

    for (final path in validFilePaths) {
      await _processFile(path, startDate, endDate, acceptable, dictionary);
    }

    for (final entry in dictionary.values) {
      entry.timestamps.sort();
    }

    return dictionary;
  }

  Future<void> _processFile(
    String path,
    DateTime startDate,
    DateTime endDate,
    Map<String, Set<String>> acceptable,
    Map<String, EmployeeEntry> dictionary,
  ) async {
    final List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      final name = path.replaceAll('\\', '/').split('/').last;
      throw GenerationException('تعذّر قراءة الملف: $name');
    }

    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      final name = path.replaceAll('\\', '/').split('/').last;
      throw GenerationException('تعذّر فك تشفير الملف: $name');
    }

    for (final sheet in excel.sheets.values) {
      _processSheet(sheet, startDate, endDate, acceptable, dictionary);
    }
  }

  void _processSheet(
    Sheet sheet,
    DateTime startDate,
    DateTime endDate,
    Map<String, Set<String>> acceptable,
    Map<String, EmployeeEntry> dictionary,
  ) {
    final rows = sheet.rows;
    if (rows.isEmpty) return;

    final colIndices = _findColumnIndices(rows[0], acceptable);
    if (!_requiredKeys.every(colIndices.containsKey)) return;

    final nameCol = colIndices['employee_name']!;
    final deptCol = colIndices['department']!;
    final dtCol = colIndices['datetime']!;

    for (var r = 1; r < rows.length; r++) {
      _processRow(
        rows[r],
        nameCol,
        deptCol,
        dtCol,
        startDate,
        endDate,
        dictionary,
      );
    }
  }

  void _processRow(
    List<Data?> row,
    int nameCol,
    int deptCol,
    int dtCol,
    DateTime startDate,
    DateTime endDate,
    Map<String, EmployeeEntry> dictionary,
  ) {
    final name = _cellText(row, nameCol);
    if (name.isEmpty) return;

    final dept = _cellText(row, deptCol);

    final dt = _parseDateTimeCell(row, dtCol);
    if (dt == null) return;

    if (!_isInRange(dt, startDate, endDate)) return;

    final entry = dictionary.putIfAbsent(
      name,
      () => EmployeeEntry(name: name, department: dept),
    );
    entry.timestamps.add(dt);
  }

  bool _isInRange(DateTime dt, DateTime startDate, DateTime endDate) {
    final date = DateTime(dt.year, dt.month, dt.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String _cellText(List<Data?> row, int col) {
    if (col >= row.length) return '';
    return row[col]?.value?.toString().trim() ?? '';
  }

  DateTime? _parseDateTimeCell(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final value = row[col]?.value;
    if (value == null) return null;
    if (value is DateTimeCellValue) return value.asDateTimeLocal();
    if (value is DateCellValue) return value.asDateTimeLocal();
    return DateTime.tryParse(value.toString().trim());
  }

  Map<String, Set<String>> _buildAcceptableMap(List<ColumnHeader> headers) {
    final map = <String, Set<String>>{};
    for (final h in headers) {
      map.putIfAbsent(h.fieldKey, () => {}).add(h.headerValue.trim());
    }
    return map;
  }

  Map<String, int> _findColumnIndices(
    List<Data?> headerRow,
    Map<String, Set<String>> acceptable,
  ) {
    final indices = <String, int>{};
    for (var col = 0; col < headerRow.length; col++) {
      final cell = headerRow[col];
      if (cell == null) continue;
      final value = cell.value?.toString().trim() ?? '';
      for (final key in _requiredKeys) {
        if (acceptable[key]?.contains(value) == true) {
          indices[key] = col;
        }
      }
    }
    return indices;
  }
}
