import '../../../shared/domain/raw_shift_employee_periods.dart';
import '../../../shared/domain/shift_employee_result.dart';

class ShiftCalculatorSettings {
  final int shiftDurationHours;
  final int zoneIntervalHours;
  final int startEndToleranceMinutes;
  final int innerToleranceMinutes;
  final int baselineHours;
  final int ceilingHours;

  const ShiftCalculatorSettings({
    required this.shiftDurationHours,
    required this.zoneIntervalHours,
    required this.startEndToleranceMinutes,
    required this.innerToleranceMinutes,
    required this.baselineHours,
    required this.ceilingHours,
  });

  int get zoneCount =>
      zoneIntervalHours == 0 ? 0 : shiftDurationHours ~/ zoneIntervalHours;
}

class ShiftOvertimeCalculator {
  ShiftEmployeeResult calculate({
    required RawShiftEmployeePeriods rawPeriods,
    required ShiftCalculatorSettings settings,
  }) {
    final periods = <ShiftPeriodDetail>[];
    int totalValidHours = 0;

    for (final period in rawPeriods.periods) {
      final detail = _calcPeriod(period: period, settings: settings);
      periods.add(detail);
      totalValidHours += detail.hoursCounted;
    }

    final cappedHours = totalValidHours.clamp(0, settings.ceilingHours);
    final overtimeHours = (cappedHours - settings.baselineHours).clamp(0, settings.ceilingHours);

    return ShiftEmployeeResult(
      name: rawPeriods.name,
      department: rawPeriods.department,
      isUnmatched: false,
      totalOvertimeHours: overtimeHours,
      periods: periods,
    );
  }

  ShiftPeriodDetail _calcPeriod({
    required RawShiftPeriod period,
    required ShiftCalculatorSettings settings,
  }) {
    final anchor = period.anchorTimestamp;
    final ts = period.timestamps;
    final duration = ts.isEmpty ? 0 : ts.last.difference(ts.first).inMinutes;
    final startDate = DateTime(anchor.year, anchor.month, anchor.day);
    final lastTs = ts.isEmpty ? anchor : ts.last;
    final endDate = DateTime(lastTs.year, lastTs.month, lastTs.day);

    final zoneResults = _buildZones(anchor, ts, settings);
    final allSatisfied = zoneResults.every((z) => z.isSatisfied);

    return ShiftPeriodDetail(
      startDate: startDate,
      endDate: endDate,
      anchorTimestamp: anchor,
      timestamps: ts,
      totalAttendanceDuration: duration,
      zoneResults: zoneResults,
      hoursCounted: allSatisfied ? 24 : 0,
      isValid: allSatisfied,
      notes: allSatisfied ? null : 'يوجد فترة زمنية بدون بصمة تحقق',
    );
  }

  List<ZoneResult> _buildZones(
    DateTime anchor,
    List<DateTime> ts,
    ShiftCalculatorSettings settings,
  ) {
    final results = <ZoneResult>[];
    final zoneCount = settings.zoneCount;

    for (int z = 0; z < zoneCount; z++) {
      final center =
          anchor.add(Duration(hours: z * settings.zoneIntervalHours));
      final toleranceMinutes = (z == 0 || z == zoneCount - 1)
          ? settings.startEndToleranceMinutes
          : settings.innerToleranceMinutes;
      final windowStart =
          center.subtract(Duration(minutes: toleranceMinutes));
      final windowEnd = center.add(Duration(minutes: toleranceMinutes));

      final zoneTs = ts
          .where((t) => !t.isBefore(windowStart) && !t.isAfter(windowEnd))
          .toList();

      results.add(ZoneResult(
        centerTime: center,
        timestamps: zoneTs,
        isSatisfied: zoneTs.isNotEmpty,
      ));
    }

    return results;
  }
}
