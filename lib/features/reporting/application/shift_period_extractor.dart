import '../../../shared/domain/employee.dart';
import '../../../shared/domain/raw_shift_employee_periods.dart';

class ShiftExtractorSettings {
  final List<String> startTimes;
  final int shiftDurationHours;
  final int startEndToleranceMinutes;
  final int periodGapHours;

  const ShiftExtractorSettings({
    required this.startTimes,
    required this.shiftDurationHours,
    required this.startEndToleranceMinutes,
    required this.periodGapHours,
  });
}

class ShiftPeriodExtractor {
  RawShiftEmployeePeriods extract({
    required Employee employee,
    required List<DateTime> timestamps,
    required ShiftExtractorSettings settings,
  }) {
    if (timestamps.isEmpty) {
      return RawShiftEmployeePeriods(
        name: employee.name,
        department: employee.department,
        periods: [],
      );
    }

    final sorted = List<DateTime>.from(timestamps)..sort();
    final periods = <RawShiftPeriod>[];

    int i = 0;
    String? fixedStartHHMM;

    // Step 1: find first timestamp matching any configured start time
    while (i < sorted.length) {
      if (_matchesAnyStartTime(
          sorted[i], settings.startTimes, settings.startEndToleranceMinutes)) {
        fixedStartHHMM = _toHHMM(sorted[i]);
        break;
      }
      i++;
    }

    if (fixedStartHHMM == null) {
      return RawShiftEmployeePeriods(
        name: employee.name,
        department: employee.department,
        periods: [],
      );
    }

    // Build periods
    while (i < sorted.length) {
      final anchor = sorted[i];
      final periodEnd =
          anchor.add(Duration(hours: settings.shiftDurationHours));

      // Collect all timestamps within [anchor, periodEnd]
      final periodTs = <DateTime>[];
      while (i < sorted.length && !sorted[i].isAfter(periodEnd)) {
        periodTs.add(sorted[i]);
        i++;
      }

      periods.add(RawShiftPeriod(
        anchorTimestamp: anchor,
        timestamps: periodTs,
      ));

      if (i >= sorted.length) break;

      // Step 4: gap detection
      final lastTs = periodTs.last;
      final gapWindowEnd =
          lastTs.add(Duration(hours: settings.periodGapHours));

      if (!sorted[i].isAfter(gapWindowEnd)) {
        // Next timestamp is within gap window.
        // The last timestamp of the current period becomes the anchor of the
        // next period (shared timestamp) — step back to include it.
        i--;
      } else {
        // Scan for next timestamp matching the fixed start time
        bool found = false;
        while (i < sorted.length) {
          if (_matchesFixedStartTime(sorted[i], fixedStartHHMM,
              settings.startEndToleranceMinutes)) {
            found = true;
            break;
          }
          i++;
        }
        if (!found) break;
      }
    }

    return RawShiftEmployeePeriods(
      name: employee.name,
      department: employee.department,
      periods: periods,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  bool _matchesAnyStartTime(
      DateTime ts, List<String> startTimes, int toleranceMinutes) {
    return startTimes
        .any((t) => _matchesFixedStartTime(ts, t, toleranceMinutes));
  }

  bool _matchesFixedStartTime(
      DateTime ts, String hhmm, int toleranceMinutes) {
    final parts = hhmm.split(':');
    final targetMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final tsMinutes = ts.hour * 60 + ts.minute;
    return (tsMinutes - targetMinutes).abs() <= toleranceMinutes;
  }

  String _toHHMM(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
}
