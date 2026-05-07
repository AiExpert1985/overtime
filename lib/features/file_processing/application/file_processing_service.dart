import 'dart:io';

import 'package:excel/excel.dart';

import '../../../shared/domain/attendance_record.dart';
import '../../../shared/domain/employee.dart';
import '../../../shared/domain/holiday.dart';

sealed class FileParseResult<T> {
  const FileParseResult();
}

class FileParseSuccess<T> extends FileParseResult<T> {
  final T data;
  const FileParseSuccess(this.data);
}

class FileParseFailure<T> extends FileParseResult<T> {
  final String errorMessage;
  const FileParseFailure(this.errorMessage);
}

class FileProcessingService {
  static const _shiftType = 'مناوب';
  static const _dailyType = 'صباحي';

  // columnHeaders: { fieldKey: [acceptedHeaderValues] }

  Future<FileParseResult<List<AttendanceRecord>>> parseAttendanceFiles(
    List<String> paths,
    Map<String, List<String>> columnHeaders,
  ) async {
    final Map<String, List<DateTime>> grouped = {};

    for (final path in paths) {
      final result = await _parseAttendanceFile(path, columnHeaders);
      switch (result) {
        case FileParseFailure(:final errorMessage):
          return FileParseFailure(errorMessage);
        case FileParseSuccess(:final data):
          for (final row in data) {
            grouped.putIfAbsent(row.$1, () => []).add(row.$2);
          }
      }
    }

    if (grouped.isEmpty) {
      return const FileParseFailure('الملف لا يحتوي على صفوف صالحة');
    }

    final records = grouped.entries.map((e) {
      final sorted = List<DateTime>.from(e.value)..sort();
      return AttendanceRecord(employeeName: e.key, fingerprints: sorted);
    }).toList();

    return FileParseSuccess(records);
  }

  Future<FileParseResult<List<(String, DateTime)>>> _parseAttendanceFile(
    String path,
    Map<String, List<String>> columnHeaders,
  ) async {
    final excel = await _openExcel(path);
    if (excel == null) {
      return const FileParseFailure('الملف لا يتطابق مع القالب المطلوب');
    }

    final nameAccepted = columnHeaders['employee_name'] ?? [];
    final dtAccepted = columnHeaders['datetime'] ?? [];

    final List<(String, DateTime)> rows = [];
    bool anySheetMatched = false;

    for (final table in excel.tables.values) {
      if (table.rows.isEmpty) continue;

      final headers = _headerRow(table.rows.first);
      final nameCol = _findColumn(headers, nameAccepted);
      final dtCol = _findColumn(headers, dtAccepted);

      if (nameCol == null || dtCol == null) continue;
      anySheetMatched = true;

      for (final row in table.rows.skip(1)) {
        final name = _cellText(row.elementAtOrNull(nameCol));
        final dt = _parseDateTime(row.elementAtOrNull(dtCol)?.value);
        if (name != null && dt != null) rows.add((name, dt));
      }
    }

    if (!anySheetMatched) {
      return const FileParseFailure('الملف لا يتطابق مع القالب المطلوب');
    }
    if (rows.isEmpty) {
      return const FileParseFailure('الملف لا يحتوي على صفوف صالحة');
    }
    return FileParseSuccess(rows);
  }

  Future<FileParseResult<List<Employee>>> parseEmployeesFiles(
    List<String> paths,
    Map<String, List<String>> columnHeaders,
  ) async {
    final List<Employee> employees = [];

    for (final path in paths) {
      final result = await _parseEmployeesFile(path, columnHeaders);
      switch (result) {
        case FileParseFailure(:final errorMessage):
          return FileParseFailure(errorMessage);
        case FileParseSuccess(:final data):
          employees.addAll(data);
      }
    }

    if (employees.isEmpty) {
      return const FileParseFailure('الملف لا يحتوي على صفوف صالحة');
    }
    return FileParseSuccess(employees);
  }

  Future<FileParseResult<List<Employee>>> _parseEmployeesFile(
    String path,
    Map<String, List<String>> columnHeaders,
  ) async {
    final excel = await _openExcel(path);
    if (excel == null) {
      return const FileParseFailure('الملف لا يتطابق مع القالب المطلوب');
    }

    final nameAccepted = columnHeaders['employee_name'] ?? [];
    final typeAccepted = columnHeaders['employment_type'] ?? [];
    final deptAccepted = columnHeaders['department'] ?? [];

    final List<Employee> employees = [];
    bool anySheetMatched = false;

    for (final table in excel.tables.values) {
      if (table.rows.isEmpty) continue;

      final headers = _headerRow(table.rows.first);
      final nameCol = _findColumn(headers, nameAccepted);
      final typeCol = _findColumn(headers, typeAccepted);
      final deptCol = _findColumn(headers, deptAccepted);

      if (nameCol == null || typeCol == null || deptCol == null) continue;
      anySheetMatched = true;

      for (final row in table.rows.skip(1)) {
        final name = _cellText(row.elementAtOrNull(nameCol));
        final typeStr = _cellText(row.elementAtOrNull(typeCol));
        final dept = _cellText(row.elementAtOrNull(deptCol));

        if (name == null || typeStr == null || dept == null) continue;

        final employmentType = _parseEmploymentType(typeStr);
        if (employmentType == null) {
          return const FileParseFailure('نوع التوظيف غير معروف في ملف الموظفين');
        }

        employees.add(Employee(
          name: name,
          employmentType: employmentType,
          department: dept,
        ));
      }
    }

    if (!anySheetMatched) {
      return const FileParseFailure('الملف لا يتطابق مع القالب المطلوب');
    }
    if (employees.isEmpty) {
      return const FileParseFailure('الملف لا يحتوي على صفوف صالحة');
    }
    return FileParseSuccess(employees);
  }

  Future<FileParseResult<List<Holiday>>> parseHolidaysFile(
    String path,
    Map<String, List<String>> columnHeaders,
  ) async {
    final excel = await _openExcel(path);
    if (excel == null) {
      return const FileParseFailure('الملف لا يتطابق مع القالب المطلوب');
    }

    final dateAccepted = columnHeaders['date'] ?? [];
    final occasionAccepted = columnHeaders['occasion'] ?? [];

    final List<Holiday> holidays = [];
    bool anySheetMatched = false;

    for (final table in excel.tables.values) {
      if (table.rows.isEmpty) continue;

      final headers = _headerRow(table.rows.first);
      final dateCol = _findColumn(headers, dateAccepted);
      final occasionCol = _findColumn(headers, occasionAccepted);

      if (dateCol == null || occasionCol == null) continue;
      anySheetMatched = true;

      for (final row in table.rows.skip(1)) {
        final date = _parseDate(row.elementAtOrNull(dateCol)?.value);
        final occasion = _cellText(row.elementAtOrNull(occasionCol));
        if (date != null && occasion != null) {
          holidays.add(Holiday(date: date, occasion: occasion));
        }
      }
    }

    if (!anySheetMatched) {
      return const FileParseFailure('الملف لا يتطابق مع القالب المطلوب');
    }
    if (holidays.isEmpty) {
      return const FileParseFailure('الملف لا يحتوي على صفوف صالحة');
    }
    return FileParseSuccess(holidays);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<Excel?> _openExcel(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return Excel.decodeBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  List<String> _headerRow(List<Data?> row) =>
      row.map((c) => c?.value?.toString().trim() ?? '').toList();

  int? _findColumn(List<String> headers, List<String> acceptable) {
    for (int i = 0; i < headers.length; i++) {
      if (acceptable.contains(headers[i])) return i;
    }
    return null;
  }

  // Returns trimmed non-empty string or null.
  String? _cellText(Data? cell) {
    final text = cell?.value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  EmploymentType? _parseEmploymentType(String value) {
    if (value == _shiftType) return EmploymentType.shift;
    if (value == _dailyType) return EmploymentType.daily;
    return null;
  }

  DateTime? _parseDateTime(CellValue? value) {
    return switch (value) {
      DateTimeCellValue() => DateTime(
          value.year,
          value.month,
          value.day,
          value.hour,
          value.minute,
          value.second,
        ),
      DateCellValue() => DateTime(value.year, value.month, value.day),
      TextCellValue() => _parseDateTimeString(value.toString().trim()),
      DoubleCellValue() => _excelSerialToDateTime(value.value),
      IntCellValue() => _excelSerialToDateTime(value.value.toDouble()),
      _ => null,
    };
  }

  DateTime? _parseDate(CellValue? value) {
    final dt = _parseDateTime(value);
    return dt == null ? null : DateTime(dt.year, dt.month, dt.day);
  }

  DateTime? _parseDateTimeString(String text) {
    // Handles ISO 8601 and "yyyy-MM-dd HH:mm:ss" (space separator)
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    // dd/MM/yyyy HH:mm[:ss]
    final m = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(text);
    if (m != null) {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6) ?? '0'),
      );
    }
    return null;
  }

  DateTime? _excelSerialToDateTime(double serial) {
    if (serial < 1) return null;
    // Excel has a leap-year bug: serial 60 = non-existent 1900-02-29
    final adjusted = serial > 60 ? serial - 1 : serial;
    final days = adjusted.floor();
    final seconds = ((adjusted - days) * 86400).round();
    return DateTime(1899, 12, 31).add(Duration(days: days, seconds: seconds));
  }
}
