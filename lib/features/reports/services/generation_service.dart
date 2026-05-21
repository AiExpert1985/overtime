import 'dart:io';
import 'dart:isolate';

import 'package:excel/excel.dart';

import '../../settings/domain/app_settings.dart';
import '../../settings/domain/column_header.dart';
import '../domain/daily_employee_entry.dart';
import '../domain/daily_period.dart';
import '../domain/employee_entry.dart';
import '../domain/schedule_detection_result.dart';
import '../domain/shift_employee_entry.dart';
import '../domain/shift_period.dart';
import '../domain/undetected_entry.dart';
import '../domain/zone_result.dart';

class GenerationException implements Exception {
  GenerationException(this.arabicMessage);
  final String arabicMessage;
}

class GenerationService {
  static const _requiredKeys = ['employee_name', 'department', 'datetime'];
  static const _offDayThreshold = 0.25;
  static const _minAttendanceDensity = 0.15;
  static const _minValidPeriods = 3;
  static const _minStartTimeConfidence = 0.60;
  static const _restGapDays = 2;

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

  // Stage 4 — Schedule Detection + Shift Period Extraction (V2)
  //
  // Replaces the old Stage 4 (type detection) and Stage 6 (shift period
  // extraction). Valid shift periods are built during detection and carried
  // directly into the shift hash table. Stage 4.5 (promote undetected to
  // daily) and Stage 6 are removed from the pipeline.
  ScheduleDetectionResult detectSchedules(
    Map<String, EmployeeEntry> dictionary,
    DateTime startDate,
    DateTime endDate,
    AppSettings settings,
  ) {
    final reportDays = endDate.difference(startDate).inDays + 1;
    final shiftTable = <String, ShiftEmployeeEntry>{};
    final dailyTable = <String, EmployeeEntry>{};
    final undetectedList = <UndetectedEntry>[];

    for (final entry in dictionary.values) {
      final result = _classifyEmployee(
        entry,
        reportDays,
        startDate,
        endDate,
        settings,
      );
      switch (result) {
        case _ShiftResult(:final startTime, :final periods):
          shiftTable[entry.name] = ShiftEmployeeEntry(
            name: entry.name,
            department: entry.department,
            detectedShiftStartTime: startTime,
            timestamps: entry.timestamps,
          )..periods = periods;
        case _DailyResult():
          dailyTable[entry.name] = entry;
        case _UndetectedResult(:final reason):
          undetectedList.add(
            UndetectedEntry(
              name: entry.name,
              department: entry.department,
              failureReason: reason,
              timestamps: entry.timestamps,
            ),
          );
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
    int reportDays,
    DateTime startDate,
    DateTime endDate,
    AppSettings settings,
  ) {
    // Step 1 — Attendance pre-check
    final attendanceDays = _groupByDay(entry.timestamps).length;
    if (attendanceDays / reportDays < _minAttendanceDensity) {
      return _UndetectedResult('أيام الحضور أقل من 15% من مدة الفترة');
    }

    // Step 2 — Build valid periods for every configured start time
    final validPeriodsMap = <String, List<ShiftPeriod>>{
      for (final st in settings.shiftStartTimes)
        st: _buildValidPeriods(
          entry.timestamps,
          st,
          startDate,
          endDate,
          settings,
        ),
    };

    // Step 3 — Find the winning start time (strict >; ties stay with first)
    var winnerStartTime = settings.shiftStartTimes.first;
    var winnerCount = validPeriodsMap[winnerStartTime]!.length;

    for (final st in settings.shiftStartTimes) {
      final count = validPeriodsMap[st]!.length;
      if (count > winnerCount) {
        winnerCount = count;
        winnerStartTime = st;
      }
    }

    // Step 4 — Classify

    // Check 1: combined period count (zone + anchor pair) below threshold → daily.
    if (winnerCount < _minValidPeriods) {
      return _DailyResult();
    }

    // Check 2: start time confidence — only required when multiple start times
    // are configured. A tie (≤ 50%) always fails the 60% threshold, so ties
    // are implicitly handled here without a separate branch.
    if (settings.shiftStartTimes.length > 1) {
      final totalValid = validPeriodsMap.values.fold(
        0,
        (sum, list) => sum + list.length,
      );
      if (totalValid == 0 ||
          winnerCount / totalValid < _minStartTimeConfidence) {
        return _UndetectedResult('وقت بداية المناوبة غير واضح');
      }
    }

    return _ShiftResult(winnerStartTime, validPeriodsMap[winnerStartTime]!);
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<ShiftPeriod> _buildValidPeriods(
    List<DateTime> timestamps,
    String startTimeStr,
    DateTime startDate,
    DateTime endDate,
    AppSettings settings,
  ) {
    final parts = startTimeStr.split(':');
    final startHour = int.parse(parts[0]);
    final startMinute = int.parse(parts[1]);

    final toleranceMinutes = settings.shiftTolerance;
    final zoneIntervalHours = settings.shiftZoneInterval;
    final shiftDurationHours = settings.shiftDuration;
    final zoneCount = settings.zoneCount;
    final minZones = (zoneCount - 1).clamp(2, zoneCount);

    final dayMap = _groupByDay(timestamps);
    final periods = <ShiftPeriod>[];
    var periodIndex = 0;

    var day = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDay = DateTime(endDate.year, endDate.month, endDate.day);

    while (!day.isAfter(lastDay)) {
      final startTimeOnDay = day.add(
        Duration(hours: startHour, minutes: startMinute),
      );
      final windowStart = startTimeOnDay.subtract(
        Duration(minutes: toleranceMinutes),
      );
      final windowEnd = startTimeOnDay.add(
        Duration(hours: shiftDurationHours, minutes: toleranceMinutes),
      );

      final windowTimestamps = timestamps
          .where((ts) => !ts.isBefore(windowStart) && !ts.isAfter(windowEnd))
          .toList();

      if (windowTimestamps.isNotEmpty) {
        final zoneResults = _buildZoneResults(
          windowTimestamps,
          windowStart,
          windowEnd,
          startTimeOnDay,
          zoneCount,
          zoneIntervalHours,
          toleranceMinutes,
        );

        final satisfiedCount = zoneResults.where((z) => z.isSatisfied).length;
        if (satisfiedCount >= minZones) {
          periods.add(
            ShiftPeriod(
              periodIndex: periodIndex,
              periodDate: _dayKey(day),
              allTimestamps: windowTimestamps,
              zoneResults: zoneResults,
            ),
          );
          periodIndex++;
        } else {
          // Zone check failed — try anchor pair fallback for this day.
          final anchor = _tryAnchorPair(
            dayMap,
            day,
            startTimeOnDay,
            zoneResults,
            periodIndex,
            toleranceMinutes,
          );
          if (anchor != null) {
            periods.add(anchor);
            periodIndex++;
          }
        }
      }

      day = day.add(const Duration(days: 1));
    }

    return periods;
  }

  // Anchor pair fallback: runs per-day when the zone check fails.
  // Detects irregular shift employees who open near S on D, have any activity
  // on D+1, rest for _restGapDays days, and return on D+4 or D+5.
  // A rest gap that is exactly the natural Fri-Sat weekend is rejected to
  // prevent daily employees on a Sun-Thu schedule from triggering this check.
  ShiftPeriod? _tryAnchorPair(
    Map<String, List<DateTime>> dayMap,
    DateTime day,
    DateTime startTimeOnDay,
    List<ZoneResult> zoneResults,
    int periodIndex,
    int toleranceMinutes,
  ) {
    // hasOpening: stamp within shift start window on D
    final openingLow = startTimeOnDay.subtract(Duration(minutes: toleranceMinutes));
    final openingHigh = startTimeOnDay.add(Duration(minutes: toleranceMinutes));
    final dStamps = dayMap[_dayKey(day)] ?? [];
    final hasOpening = dStamps.any(
      (ts) => !ts.isBefore(openingLow) && !ts.isAfter(openingHigh),
    );
    if (!hasOpening) return null;

    // hasActivity: any stamp on D+1 at any time
    final dayPlus1 = day.add(const Duration(days: 1));
    if (!dayMap.containsKey(_dayKey(dayPlus1))) return null;

    // hasRestGap: no stamps for the next _restGapDays days after D+1,
    // and not both gap days are the natural Fri-Sat weekend.
    var gapClear = true;
    for (var i = 2; i < 2 + _restGapDays; i++) {
      if (dayMap.containsKey(_dayKey(day.add(Duration(days: i))))) {
        gapClear = false;
        break;
      }
    }
    if (!gapClear) return null;

    final dayPlus2 = day.add(const Duration(days: 2));
    final dayPlus3 = day.add(const Duration(days: 3));
    if (dayPlus2.weekday == DateTime.friday &&
        dayPlus3.weekday == DateTime.saturday) {
      return null;
    }

    // hasReturn: any stamp on D+4 or D+5
    final hasReturn =
        dayMap.containsKey(_dayKey(day.add(const Duration(days: 4)))) ||
        dayMap.containsKey(_dayKey(day.add(const Duration(days: 5))));
    if (!hasReturn) return null;

    final anchorTimestamps = [
      ...(dayMap[_dayKey(day)] ?? <DateTime>[]),
      ...(dayMap[_dayKey(dayPlus1)] ?? <DateTime>[]),
    ]..sort();

    return ShiftPeriod(
      periodIndex: periodIndex,
      periodDate: _dayKey(day),
      allTimestamps: anchorTimestamps,
      zoneResults: zoneResults,
    );
  }

  // Stage 5 — Off-Day Detection
  Set<DateTime> detectOffDays(
    Map<String, EmployeeEntry> dailyTable,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (dailyTable.isEmpty) return {};

    final totalEmployees = dailyTable.length;
    final employeeDayMaps = dailyTable.values
        .map((e) => _groupByDay(e.timestamps))
        .toList();
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

  // Stage 6 — Daily Period Extractor
  Map<String, DailyEmployeeEntry> extractDailyPeriods(
    Map<String, EmployeeEntry> dailyTable,
    Set<DateTime> offDays,
  ) {
    final result = <String, DailyEmployeeEntry>{};

    for (final entry in dailyTable.values) {
      final dayMap = _groupByDay(entry.timestamps);
      final periods = <DailyPeriod>[];
      var periodIndex = 0;

      final sortedKeys = dayMap.keys.toList()..sort();
      for (final dateStr in sortedKeys) {
        final timestamps = dayMap[dateStr]!;
        final date = DateTime.parse(dateStr);
        final dayType = offDays.contains(date) ? 'off' : 'regular';
        periods.add(
          DailyPeriod(
            periodIndex: periodIndex,
            date: dateStr,
            weekday: _arabicWeekday(date.weekday),
            dayType: dayType,
            allTimestamps: timestamps,
          ),
        );
        periodIndex++;
      }

      final dailyEntry = DailyEmployeeEntry(
        name: entry.name,
        department: entry.department,
        timestamps: entry.timestamps,
      );
      dailyEntry.periods = periods;
      result[entry.name] = dailyEntry;
    }

    return result;
  }

  static const _arabicWeekdays = [
    '', // placeholder — DateTime.weekday is 1-based
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  String _arabicWeekday(int weekday) => _arabicWeekdays[weekday];

  // Runs Stages 4–8 in a background isolate so the UI thread stays free.
  static Future<({
    Map<String, ShiftEmployeeEntry> shiftTable,
    Map<String, DailyEmployeeEntry> dailyEntries,
    List<UndetectedEntry> undetectedList,
  })> runCpuPipeline({
    required Map<String, EmployeeEntry> dictionary,
    required DateTime startDate,
    required DateTime endDate,
    required AppSettings settings,
  }) {
    return Isolate.run(() {
      final svc = GenerationService();
      final schedules = svc.detectSchedules(dictionary, startDate, endDate, settings);
      final offDays = svc.detectOffDays(schedules.dailyTable, startDate, endDate);
      final dailyEntries = svc.extractDailyPeriods(schedules.dailyTable, offDays);
      svc.calculateShiftOvertime(schedules.shiftTable, settings);
      svc.calculateDailyOvertime(dailyEntries, settings);
      return (
        shiftTable: schedules.shiftTable,
        dailyEntries: dailyEntries,
        undetectedList: schedules.undetectedList,
      );
    });
  }

  // Stage 7 — Shift Overtime Calculator
  Map<String, ShiftEmployeeEntry> calculateShiftOvertime(
    Map<String, ShiftEmployeeEntry> shiftTable,
    AppSettings settings,
  ) {
    for (final entry in shiftTable.values) {
      var totalHoursCounted = 0;

      for (final period in entry.periods) {
        _enrichShiftPeriod(period);
        totalHoursCounted += period.hoursCounted!;
      }

      final cappedHours = totalHoursCounted.clamp(
        0,
        settings.shiftCeilingHours,
      );
      final overtime = cappedHours - settings.shiftBaselineHours;
      entry.overtimeMinutes = overtime > 0 ? overtime * 60 : 0;
    }

    return shiftTable;
  }

  // Stage 8 — Daily Overtime Calculator
  Map<String, DailyEmployeeEntry> calculateDailyOvertime(
    Map<String, DailyEmployeeEntry> dailyEntries,
    AppSettings settings,
  ) {
    final parts = settings.dailyStartTime.split(':');
    final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final endTimeMinutes = startMinutes + settings.dailyWorkDuration * 60;
    final deadlineMinutes = startMinutes + settings.dailyDelayAllowance;
    final maxOvertimeMinutes = settings.dailyMaxOvertime * 60;

    for (final entry in dailyEntries.values) {
      var total = 0;
      var regular = 0;
      var off = 0;
      for (final period in entry.periods) {
        _enrichDailyPeriod(
          period,
          endTimeMinutes,
          deadlineMinutes,
          maxOvertimeMinutes,
        );
        final mins = period.overtimeMinutes!;
        total += mins;
        if (period.dayType == 'regular') {
          regular += mins;
        } else {
          off += mins;
        }
      }
      entry.totalOvertimeMinutes = total;
      entry.regularOvertimeMinutes = regular;
      entry.offOvertimeMinutes = off;
    }

    return dailyEntries;
  }

  void _enrichDailyPeriod(
    DailyPeriod period,
    int endTimeMinutes,
    int deadlineMinutes,
    int maxOvertimeMinutes,
  ) {
    final timestamps = period.allTimestamps;
    period.totalAttendanceDuration = timestamps.length >= 2
        ? timestamps.last.difference(timestamps.first).inMinutes
        : 0;

    if (period.dayType == 'regular') {
      _enrichRegularDay(
        period,
        endTimeMinutes,
        deadlineMinutes,
        maxOvertimeMinutes,
      );
    } else {
      _enrichOffDay(period, maxOvertimeMinutes);
    }
  }

  void _enrichRegularDay(
    DailyPeriod period,
    int endTimeMinutes,
    int deadlineMinutes,
    int maxOvertimeMinutes,
  ) {
    final timestamps = period.allTimestamps;

    if (timestamps.length < 2) {
      period.isValid = false;
      period.overtimeMinutes = 0;
      period.notes = 'بصمة واحدة فقط';
      return;
    }

    final firstMinutes = timestamps.first.hour * 60 + timestamps.first.minute;
    if (firstMinutes > deadlineMinutes) {
      period.isValid = false;
      period.overtimeMinutes = 0;
      period.notes = 'البصمة الأولى تتجاوز وقت البداية مع وقت السماح';
      return;
    }

    final lastMinutes = timestamps.last.hour * 60 + timestamps.last.minute;
    period.isValid = true;
    period.overtimeMinutes = (lastMinutes - endTimeMinutes).clamp(
      0,
      maxOvertimeMinutes,
    );
    period.notes = null;
  }

  void _enrichOffDay(DailyPeriod period, int maxOvertimeMinutes) {
    final timestamps = period.allTimestamps;

    if (timestamps.length < 2) {
      period.isValid = false;
      period.overtimeMinutes = 0;
      period.notes = 'بصمة واحدة فقط';
      return;
    }

    final raw = timestamps.last.difference(timestamps.first).inMinutes;
    period.isValid = true;
    period.overtimeMinutes = raw.clamp(0, maxOvertimeMinutes);
    period.notes = null;
  }

  void _enrichShiftPeriod(ShiftPeriod period) {
    final isValid = period.zoneResults.every((z) => z.isSatisfied);
    final first = period.allTimestamps.first;
    final last = period.allTimestamps.last;

    period.endDate =
        '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
    period.totalAttendanceDuration = last.difference(first).inMinutes;
    period.isValid = isValid;
    period.hoursCounted = isValid ? 24 : 0;
    period.notes = isValid ? null : 'يوجد فترة زمنية بدون بصمة تحقق';
  }

  List<ZoneResult> _buildZoneResults(
    List<DateTime> timestamps,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime startTimeOnDay,
    int zoneCount,
    int zoneIntervalHours,
    int toleranceMinutes,
  ) {
    final zones = <ZoneResult>[];

    for (var i = 0; i < zoneCount; i++) {
      final zoneStart = windowStart.add(Duration(hours: i * zoneIntervalHours));
      final zoneEnd = (i < zoneCount - 1)
          ? windowStart.add(Duration(hours: (i + 1) * zoneIntervalHours))
          : windowEnd;

      final zoneCenter = startTimeOnDay.add(
        Duration(hours: i * zoneIntervalHours),
      );
      final centerLow = zoneCenter.subtract(
        Duration(minutes: toleranceMinutes),
      );
      final centerHigh = zoneCenter.add(Duration(minutes: toleranceMinutes));

      final zoneTimestamps = timestamps.where((ts) {
        if (i < zoneCount - 1) {
          return !ts.isBefore(zoneStart) && ts.isBefore(zoneEnd);
        } else {
          return !ts.isBefore(zoneStart) && !ts.isAfter(zoneEnd);
        }
      }).toList();

      final isSatisfied = zoneTimestamps.any(
        (ts) => !ts.isBefore(centerLow) && !ts.isAfter(centerHigh),
      );

      zones.add(
        ZoneResult(
          zoneIndex: i,
          startTime: zoneStart,
          endTime: zoneEnd,
          timestamps: zoneTimestamps,
          isSatisfied: isSatisfied,
        ),
      );
    }

    return zones;
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

sealed class _DetectResult {}

final class _ShiftResult extends _DetectResult {
  _ShiftResult(this.startTime, this.periods);
  final String startTime;
  final List<ShiftPeriod> periods;
}

final class _DailyResult extends _DetectResult {}

final class _UndetectedResult extends _DetectResult {
  _UndetectedResult(this.reason);
  final String reason;
}
