import 'dart:io';

import 'package:excel/excel.dart';

import '../../settings/domain/column_header.dart';
import '../domain/picked_file.dart';

class FileValidationService {
  static const _requiredKeys = ['employee_name', 'department', 'datetime'];

  static const _errTemplate = 'الملف لا يتطابق مع القالب المطلوب';
  static const _errNoRows = 'الملف لا يحتوي على صفوف صالحة';

  Future<PickedFile> validate(
    String path,
    String name,
    List<ColumnHeader> headers,
  ) async {
    final acceptable = _buildAcceptableMap(headers);

    final List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      return _invalid(name, path, _errTemplate);
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      return _invalid(name, path, _errTemplate);
    }

    var anySheetHadHeaders = false;

    for (final sheet in excel.sheets.values) {
      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      final colIndices = _findColumnIndices(rows[0], acceptable);
      if (!_requiredKeys.every(colIndices.containsKey)) continue;

      anySheetHadHeaders = true;

      if (_hasValidRow(rows, colIndices)) {
        return PickedFile(name: name, path: path, isValid: true);
      }
    }

    return _invalid(
      name,
      path,
      anySheetHadHeaders ? _errNoRows : _errTemplate,
    );
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

  bool _hasValidRow(List<List<Data?>> rows, Map<String, int> colIndices) {
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final allPresent = _requiredKeys.every((key) {
        final col = colIndices[key]!;
        final cell = col < row.length ? row[col] : null;
        return (cell?.value?.toString().trim() ?? '').isNotEmpty;
      });
      if (allPresent) return true;
    }
    return false;
  }

  PickedFile _invalid(String name, String path, String message) {
    return PickedFile(
      name: name,
      path: path,
      isValid: false,
      errorMessage: message,
    );
  }
}
