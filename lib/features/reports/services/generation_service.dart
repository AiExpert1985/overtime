import 'dart:io';

import 'package:excel/excel.dart';

import '../../settings/domain/app_settings.dart';
import '../../settings/domain/column_header.dart';
import '../domain/employee_entry.dart';
import '../domain/schedule_detection_result.dart';
import '../domain/shift_employee_entry.dart';
import '../domain/undetected_entry.dart';

class GenerationException implements Exception {
  GenerationException(this.arabicMessage);
  final String arabicMessage;
}

class GenerationService {
  static const _requiredKeys = ['employee_name', 'department', 'datetime'];
  static const _offDayThreshold = 0.25;

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

  // Stage 5 — Off-Day Detection
  Set<DateTime> detectOffDays(
    Map<String, EmployeeEntry> dailyTable,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (dailyTable.isEmpty) return {};

    final totalEmployees = dailyTable.length;
    final employeeDayMaps =
        dailyTable.values.map((e) => _groupByDay(e.timestamps)).toList();
    final offDays = <DateTime>{};

    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      final key =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      var attendedCount = 0;
      for (final dayMap in employeeDayMaps) {
        if (dayMap.containsKey(key)) attendedCount++;
      }
      if (attendedCount / totalEmployees < _offDayThreshold) {
        offDays.add(current);
      }
      current = current.add(const Duration(days: 1));
    }

    return offDays;
  }

  // Stage 4 — Schedule Detection
  ScheduleDetectionResult detectSchedules(
    Map<String, EmployeeEntry> dictionary,
    DateTime startDate,
    DateTime endDate,
    AppSettings settings,
  ) {
    final periodDays = endDate.difference(startDate).inDays + 1;
    final shiftTable = <String, ShiftEmployeeEntry>{};
    final dailyTable = <String, EmployeeEntry>{};
    final undetectedList = <UndetectedEntry>[];

    for (final entry in dictionary.values) {
      final result = _classifyEmployee(entry, periodDays, settings);
      switch (result) {
        case _ShiftResult(:final startTime):
          shiftTable[entry.name] = ShiftEmployeeEntry(
            name: entry.name,
            department: entry.department,
            detectedShiftStartTime: startTime,
            timestamps: entry.timestamps,
          );
        case _DailyResult():
          dailyTable[entry.name] = entry;
        case _UndetectedResult(:final reason):
          undetectedList.add(UndetectedEntry(
            name: entry.name,
            department: entry.department,
            failureReason: reason,
          ));
      }
    }

    return ScheduleDetectionResult(
      shiftTable: shiftTable,
      dailyTable: dailyTable,
      undetectedList: undetectedList,
    );
  }

  _DetectResult _classifyEmployee(
    EmployeeEntry entry,
    int periodDays,
    AppSettings settings,
  ) {
    final dayMap = _groupByDay(entry.timestamps);

    // Pre-check: raw attendance days >= 20% of period
    if (dayMap.length / periodDays < 0.20) {
      return _UndetectedResult('أيام الحضور أقل من 20% من مدة الفترة');
    }

    // Stage 1: usable days (>= 2 timestamps) >= 20% of period
    final usableDays =
        dayMap.values.where((ts) => ts.length >= 2).toList();
    if (usableDays.length / periodDays < 0.20) {
      return _UndetectedResult('أيام الحضور الصالحة أقل من 20% من مدة الفترة');
    }

    // Stage 2: zone bucketing
    final shiftDays = <List<DateTime>>[];
    var dailyCount = 0;

    for (final dayTimestamps in usableDays) {
      final activeZones = <int>{};
      for (final ts in dayTimestamps) {
        activeZones.add(ts.hour ~/ settings.shiftZoneInterval);
      }
      if (activeZones.length == 2) {
        dailyCount++;
      } else if (activeZones.length >= 3) {
        shiftDays.add(dayTimestamps);
      }
      // 1 active zone: discard
    }

    final shiftCount = shiftDays.length;

    // Stage 3: employment type vote (>= 75% confidence)
    final total = shiftCount + dailyCount;
    if (total == 0) {
      return _UndetectedResult('نوع التوظيف غير واضح');
    }

    final winning = shiftCount > dailyCount ? shiftCount : dailyCount;
    if (winning / total < 0.75) {
      return _UndetectedResult('نوع التوظيف غير واضح');
    }

    if (dailyCount > shiftCount) {
      return _DailyResult();
    }

    // Confirmed shift — detect start time (Algorithm 2)
    return _detectShiftStartTime(shiftDays, settings);
  }

  _DetectResult _detectShiftStartTime(
    List<List<DateTime>> shiftDays,
    AppSettings settings,
  ) {
    final buckets = <String, int>{
      for (final st in settings.shiftStartTimes) st: 0,
    };
    var unmatchedCount = 0;

    for (final dayTimestamps in shiftDays) {
      var matched = false;
      for (final startTime in settings.shiftStartTimes) {
        if (_anyTimestampWithinTolerance(
          dayTimestamps,
          startTime,
          settings.shiftTolerance,
        )) {
          buckets[startTime] = buckets[startTime]! + 1;
          matched = true;
          // intentionally no break — one day may match multiple start times
        }
      }
      if (!matched) unmatchedCount++;
    }

    // Find start time bucket with the most days
    String? winner;
    var winnerCount = 0;
    for (final entry in buckets.entries) {
      if (entry.value > winnerCount) {
        winnerCount = entry.value;
        winner = entry.key;
      }
    }

    // Denominator: all start time bucket days + unmatched
    final totalBucketDays = buckets.values.fold(0, (a, b) => a + b);
    final denominator = totalBucketDays + unmatchedCount;

    if (winner == null || denominator == 0 || winnerCount / denominator < 0.60) {
      return _UndetectedResult('وقت بداية المناوبة غير واضح');
    }

    return _ShiftResult(winner);
  }

  Map<String, List<DateTime>> _groupByDay(List<DateTime> timestamps) {
    final map = <String, List<DateTime>>{};
    for (final ts in timestamps) {
      final key =
          '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(ts);
    }
    return map;
  }

  bool _anyTimestampWithinTolerance(
    List<DateTime> dayTimestamps,
    String startTimeStr,
    int toleranceMinutes,
  ) {
    final parts = startTimeStr.split(':');
    final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    for (final ts in dayTimestamps) {
      final tsMinutes = ts.hour * 60 + ts.minute;
      if ((tsMinutes - startMinutes).abs() <= toleranceMinutes) return true;
    }
    return false;
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

// Internal result types for schedule detection
sealed class _DetectResult {}

final class _ShiftResult extends _DetectResult {
  _ShiftResult(this.startTime);
  final String startTime;
}

final class _DailyResult extends _DetectResult {}

final class _UndetectedResult extends _DetectResult {
  _UndetectedResult(this.reason);
  final String reason;
}
