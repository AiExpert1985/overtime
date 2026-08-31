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
  // The winning start time must beat the runner-up by this factor. Unlike a
  // share of the total, this does not change as more start times are added.
  static const _startTimeWinMargin = 1.5;
  static const _restGapDays = 2;
  // Longest trailing spill into the next month that is treated as look-ahead
  // rather than as a report that genuinely spans two months.
  static const _maxLookAheadDays = 2;
  // Floor for the daily gate, so a very short report cannot be satisfied by a
  // couple of stray morning stamps.
  static const _minMorningDays = 5.0;
  // How far before daily_start_time an arrival can still count as a morning
  // arrival. The entry test is otherwise one-sided — arriving early is never a
  // violation — but without a lower bound a night worker leaving in the small
  // hours reads as a daily employee arriving very early. Expressed relative to
  // the configured start time rather than as a fixed hour, so it stays correct
  // if the daily schedule is ever moved off the morning.
  static const _morningArrivalLead = 120;
  // Edge tolerance used by classification only, never by overtime validity.
  // Deliberately wider than shift_edge_tolerance: deciding whether someone
  // works shifts is a different question from whether a period met the rules,
  // and keeping them apart means tuning shift_edge_tolerance changes who earns
  // overtime without changing who is classified as a shift worker.
  static const _detectionEdgeTolerance = 120;

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

    final openWorkingDays = _countOpenWorkingDays(
      dictionary,
      startDate,
      endDate,
    );

    for (final entry in dictionary.values) {
      final result = _classifyEmployee(
        entry,
        reportDays,
        startDate,
        endDate,
        settings,
        openWorkingDays,
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

  // Days the organisation was actually open, measured from attendance rather
  // than assumed from the calendar. A month containing an extended holiday has
  // far fewer real working days than non-weekend days, and thresholds built on
  // the calendar reject an entire workforce when that happens.
  int _countOpenWorkingDays(
    Map<String, EmployeeEntry> dictionary,
    DateTime startDate,
    DateTime endDate,
  ) {
    final headcount = dictionary.length;
    if (headcount == 0) return 0;

    final presentPerDay = <String, int>{};
    for (final entry in dictionary.values) {
      for (final key in _groupByDay(entry.timestamps).keys) {
        presentPerDay.update(key, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    var open = 0;
    var day = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDay = DateTime(endDate.year, endDate.month, endDate.day);
    while (!day.isAfter(lastDay)) {
      final isWeekend =
          day.weekday == DateTime.friday || day.weekday == DateTime.saturday;
      if (!isWeekend) {
        final present = presentPerDay[_dayKey(day)] ?? 0;
        if (present / headcount >= _offDayThreshold) open++;
      }
      day = day.add(const Duration(days: 1));
    }
    return open;
  }

  _DetectResult _classifyEmployee(
    EmployeeEntry entry,
    int reportDays,
    DateTime startDate,
    DateTime endDate,
    AppSettings settings,
    int openWorkingDays,
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

    // Check 1: combined period count (zone + anchor pair) below threshold.
    // Run daily validation gate before classifying as daily.
    if (winnerCount < _minValidPeriods) {
      return _runDailyValidationGate(
        entry.timestamps,
        settings,
        openWorkingDays,
      );
    }

    // Check 2: start time confidence — only required when multiple start times
    // are configured. The winner is compared against the runner-up rather than
    // against the sum of all candidates. Zones overlap, so one employee scores
    // under several start times; measuring against the sum meant every extra
    // configured start time diluted the winner's share, and configuring the
    // app more thoroughly silently made detection worse. A tie fails, since
    // the winner cannot then clear the margin.
    if (settings.shiftStartTimes.length > 1) {
      var runnerUpCount = 0;
      for (final st in settings.shiftStartTimes) {
        if (st == winnerStartTime) continue;
        final count = validPeriodsMap[st]!.length;
        if (count > runnerUpCount) runnerUpCount = count;
      }
      if (winnerCount == 0 ||
          winnerCount < runnerUpCount * _startTimeWinMargin) {
        return _UndetectedResult('وقت بداية المناوبة غير واضح');
      }
    }

    return _ShiftResult(winnerStartTime, validPeriodsMap[winnerStartTime]!);
  }

  // Confirms an employee who failed the shift check really does follow the
  // morning schedule, before accepting them as daily.
  //
  // Two properties matter here. The threshold counts days the organisation was
  // actually open, not calendar weekdays, so a holiday month does not reject
  // everyone. And the entry test is one-sided: arriving before the start time
  // is never a violation, matching the rule the daily calculator applies.
  _DetectResult _runDailyValidationGate(
    List<DateTime> timestamps,
    AppSettings settings,
    int openWorkingDays,
  ) {
    if (openWorkingDays == 0) return _DailyResult();

    final parts = settings.dailyStartTime.split(':');
    final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final earliestEntry = startMinutes - _morningArrivalLead;
    final latestEntry = startMinutes + settings.dailyDelayAllowance;

    final dayMap = _groupByDay(timestamps);
    var morningDays = 0;
    for (final stamps in dayMap.values) {
      // stamps are sorted, so the earliest is the arrival for that day
      final firstMinutes = stamps.first.hour * 60 + stamps.first.minute;
      if (firstMinutes >= earliestEntry && firstMinutes <= latestEntry) {
        morningDays++;
      }
    }

    final ratioThreshold = openWorkingDays * 0.50;
    final threshold =
        ratioThreshold < _minMorningDays ? _minMorningDays : ratioThreshold;
    if (morningDays < threshold) {
      return _UndetectedResult(
        'لا يتوافق مع تعليمات المناوبة أو الدوام الصباحي',
      );
    }

    return _DailyResult();
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

    final edgeTolerance = settings.shiftEdgeTolerance;
    final innerTolerance = settings.shiftInnerTolerance;
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
      // The period window spans B1's bucket start to BN's bucket end, both of
      // which are set by the edge tolerance.
      final windowStart = startTimeOnDay.subtract(
        const Duration(minutes: _detectionEdgeTolerance),
      );
      final windowEnd = startTimeOnDay.add(
        Duration(
          hours: shiftDurationHours,
          minutes: _detectionEdgeTolerance,
        ),
      );

      final windowTimestamps = timestamps
          .where((ts) => !ts.isBefore(windowStart) && !ts.isAfter(windowEnd))
          .toList();

      if (windowTimestamps.isNotEmpty) {
        final (zoneResults, wideSatisfied) = _buildZoneResults(
          windowTimestamps,
          windowStart,
          windowEnd,
          startTimeOnDay,
          zoneCount,
          zoneIntervalHours,
          shiftDurationHours,
          edgeTolerance,
          innerTolerance,
        );

        final satisfiedCount = wideSatisfied;
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
            _detectionEdgeTolerance,
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
    int edgeTolerance,
  ) {
    // hasOpening: stamp within shift start window on D. Uses the edge
    // tolerance — this is the same question B1 asks elsewhere.
    final openingLow = startTimeOnDay.subtract(
      Duration(minutes: edgeTolerance),
    );
    final openingHigh = startTimeOnDay.add(Duration(minutes: edgeTolerance));
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

  // The report range is a calendar month plus a trailing day or two, so a shift
  // period anchored on the last of the month can read its closing stamps. Those
  // trailing days belong to the NEXT month's report — a daily employee must not
  // accrue overtime on them here and again there.
  //
  // Returns the first day to exclude, or null when there is nothing to trim.
  // A range that genuinely spans months (not a short spill) is left alone, so a
  // non-month report never silently loses its later weeks.
  DateTime? _dailyCutoff(DateTime startDate, DateTime endDate) {
    final sameMonth =
        endDate.year == startDate.year && endDate.month == startDate.month;
    if (sameMonth) return null;
    if (endDate.day > _maxLookAheadDays) return null;
    return DateTime(startDate.year, startDate.month + 1, 1);
  }

  // Stage 6 — Daily Period Extractor
  Map<String, DailyEmployeeEntry> extractDailyPeriods(
    Map<String, EmployeeEntry> dailyTable,
    Set<DateTime> offDays,
    DateTime startDate,
    DateTime endDate,
  ) {
    final result = <String, DailyEmployeeEntry>{};
    final cutoff = _dailyCutoff(startDate, endDate);

    for (final entry in dailyTable.values) {
      final dayMap = _groupByDay(entry.timestamps);
      final periods = <DailyPeriod>[];
      var periodIndex = 0;

      final sortedKeys = dayMap.keys.toList()..sort();
      for (final dateStr in sortedKeys) {
        final timestamps = dayMap[dateStr]!;
        final date = DateTime.parse(dateStr);
        if (cutoff != null && !date.isBefore(cutoff)) continue;
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

  // Runs the full pipeline (Stages 3–8) in a background isolate so the UI
  // thread stays free from the moment the generate button is tapped. Excel
  // decoding (Stage 3) is CPU-bound synchronous work even though the file
  // read is async — running it here prevents any main-isolate freeze.
  static Future<({
    Map<String, ShiftEmployeeEntry> shiftTable,
    Map<String, DailyEmployeeEntry> dailyEntries,
    List<UndetectedEntry> undetectedList,
  })> runFullPipeline({
    required List<String> validFilePaths,
    required DateTime startDate,
    required DateTime endDate,
    required AppSettings settings,
    required List<ColumnHeader> headers,
  }) {
    // Defence in depth: the settings screen blocks this, but settings could
    // have been altered outside that flow. Checked on the main isolate so the
    // failure surfaces through the normal generation error path.
    if (!settings.hasValidTolerances) {
      throw GenerationException(
        'إعدادات المناوبة غير صالحة: يجب ألا تتجاوز سماحية البصمة '
        '${settings.maxToleranceMinutes} دقيقة مع ساعات البصمة الحالية',
      );
    }

    return Isolate.run(() async {
      final svc = GenerationService();
      final dictionary = await svc.buildDictionary(
        validFilePaths,
        startDate,
        endDate,
        headers,
      );
      final schedules = svc.detectSchedules(dictionary, startDate, endDate, settings);
      final offDays = svc.detectOffDays(schedules.dailyTable, startDate, endDate);
      final dailyEntries = svc.extractDailyPeriods(
        schedules.dailyTable,
        offDays,
        startDate,
        endDate,
      );
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
        _enrichShiftPeriod(period, settings);
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

    // Both checks always run — neither short-circuits the other, so a single
    // late stamp reports both reasons.
    final reasons = <String>{};

    if (timestamps.length < 2) {
      reasons.add('بصمة واحدة فقط');
    }

    if (timestamps.isNotEmpty) {
      final firstMinutes = timestamps.first.hour * 60 + timestamps.first.minute;
      if (firstMinutes > deadlineMinutes) {
        reasons.add('البصمة الأولى تتجاوز وقت البداية مع وقت السماح');
      }
    }

    period.notes = reasons;

    if (reasons.isNotEmpty) {
      period.isValid = false;
      period.overtimeMinutes = 0;
      return;
    }

    final lastMinutes = timestamps.last.hour * 60 + timestamps.last.minute;
    period.isValid = true;
    period.overtimeMinutes = (lastMinutes - endTimeMinutes).clamp(
      0,
      maxOvertimeMinutes,
    );
  }

  void _enrichOffDay(DailyPeriod period, int maxOvertimeMinutes) {
    final timestamps = period.allTimestamps;

    // The entry-time check does not apply to off days, so this is the only
    // reason an off day can carry.
    if (timestamps.length < 2) {
      period.isValid = false;
      period.overtimeMinutes = 0;
      period.notes = {'بصمة واحدة فقط'};
      return;
    }

    final raw = timestamps.last.difference(timestamps.first).inMinutes;
    period.isValid = true;
    period.overtimeMinutes = raw.clamp(0, maxOvertimeMinutes);
    period.notes = {};
  }

  // Every check runs on every period — none short-circuits another, so the
  // order below does not affect the outcome. A period is valid only when no
  // check contributed a reason.
  void _enrichShiftPeriod(ShiftPeriod period, AppSettings settings) {
    final zones = period.zoneResults;
    final first = period.allTimestamps.first;
    final last = period.allTimestamps.last;
    final duration = last.difference(first).inMinutes;

    final reasons = <String>{};

    if (zones.isNotEmpty && !zones.first.isSatisfied) {
      reasons.add('بصمة الدخول خارج الوقت المسموح به');
    }

    final innerCount = zones.length - 2;
    if (innerCount > 0) {
      final innerZones = zones.sublist(1, zones.length - 1);
      if (innerZones.any((z) => !z.isSatisfied)) {
        reasons.add(
          'لم يتم استيفاء العدد المطلوب من نقاط التحقق الداخلية '
          '(المطلوب: $innerCount نقطة)',
        );
      }
    }

    if (zones.length > 1 && !zones.last.isSatisfied) {
      reasons.add('بصمة الخروج خارج الوقت المسموح به');
    }

    final minimumDuration =
        settings.shiftDuration * 60 - settings.shiftDurationTolerance;
    if (duration < minimumDuration) {
      reasons.add('مدة الحضور الفعلية أقل من الحد الأدنى المطلوب');
    }

    final isValid = reasons.isEmpty;

    period.endDate =
        '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
    period.totalAttendanceDuration = duration;
    period.isValid = isValid;
    period.hoursCounted = isValid ? 24 : 0;
    period.notes = reasons;
  }

  // Zone layout, built in three ordered steps.
  //
  // 1. Centers — B1 at the start time, inner zones every zone_interval, BN at
  //    start + shift_duration.
  // 2. Buckets — boundaries sit at the midpoint between neighbouring centers.
  //    The two outer edges have no neighbour, so the edge tolerance is used
  //    there instead. Buckets are contiguous and non-overlapping, so every
  //    timestamp in the period window falls into exactly one bucket.
  // 3. Validity windows — center +/- its own tolerance. Centered inside the
  //    bucket for inner zones; for B1 and BN the window sits at the outer end
  //    of the bucket, not its middle. That asymmetry is intended.
  //
  // Boundaries belong to the zone that opens there (exclusive on the end they
  // close), except the final boundary of the period, which is inclusive so the
  // closing timestamp is never dropped.
  (List<ZoneResult>, int) _buildZoneResults(
    List<DateTime> timestamps,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime startTimeOnDay,
    int zoneCount,
    int zoneIntervalHours,
    int shiftDurationHours,
    int edgeTolerance,
    int innerTolerance,
  ) {
    final lastIndex = zoneCount - 1;

    // Step 1 — centers.
    final centers = <DateTime>[
      for (var i = 0; i < lastIndex; i++)
        startTimeOnDay.add(Duration(hours: i * zoneIntervalHours)),
      startTimeOnDay.add(Duration(hours: shiftDurationHours)),
    ];

    // Step 2 — bucket boundaries from the midpoints between centers.
    final bounds = <DateTime>[windowStart];
    for (var i = 0; i < lastIndex; i++) {
      final gap = centers[i + 1].difference(centers[i]);
      bounds.add(centers[i].add(gap ~/ 2));
    }
    bounds.add(windowEnd);

    final zones = <ZoneResult>[];
    var wideSatisfied = 0;

    for (var i = 0; i < zoneCount; i++) {
      final isLast = i == lastIndex;
      final zoneStart = bounds[i];
      final zoneEnd = bounds[i + 1];

      // Step 3 — validity window.
      final tolerance = (i == 0 || isLast) ? edgeTolerance : innerTolerance;
      final centerLow = centers[i].subtract(Duration(minutes: tolerance));
      final centerHigh = centers[i].add(Duration(minutes: tolerance));

      final zoneTimestamps = timestamps.where((ts) {
        if (!isLast) {
          return !ts.isBefore(zoneStart) && ts.isBefore(zoneEnd);
        }
        return !ts.isBefore(zoneStart) && !ts.isAfter(zoneEnd);
      }).toList();

      final isSatisfied = zoneTimestamps.any((ts) {
        if (ts.isBefore(centerLow)) return false;
        return isLast ? !ts.isAfter(centerHigh) : ts.isBefore(centerHigh);
      });

      // Detection uses a wider edge window than overtime validity does.
      final wideTol = (i == 0 || isLast) ? _detectionEdgeTolerance : tolerance;
      final wideLow = centers[i].subtract(Duration(minutes: wideTol));
      final wideHigh = centers[i].add(Duration(minutes: wideTol));
      if (zoneTimestamps.any(
        (ts) => !ts.isBefore(wideLow) && !ts.isAfter(wideHigh),
      )) {
        wideSatisfied++;
      }

      zones.add(
        ZoneResult(
          zoneIndex: i,
          startTime: zoneStart,
          endTime: zoneEnd,
          windowStart: centerLow,
          windowEnd: centerHigh,
          timestamps: zoneTimestamps,
          isSatisfied: isSatisfied,
        ),
      );
    }

    return (zones, wideSatisfied);
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
