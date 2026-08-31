import 'dart:convert';

class AppSettings {
  const AppSettings({
    required this.dailyStartTime,
    required this.dailyWorkDuration,
    required this.dailyMaxOvertime,
    required this.dailyDelayAllowance,
    required this.shiftStartTimes,
    required this.shiftDuration,
    required this.shiftZoneInterval,
    required this.shiftEdgeTolerance,
    required this.shiftInnerTolerance,
    required this.shiftDurationTolerance,
    required this.shiftBaselineHours,
    required this.shiftCeilingHours,
    required this.roundingMode,
    required this.maxReportDateRange,
  });

  final String dailyStartTime;
  final int dailyWorkDuration;
  final int dailyMaxOvertime;
  final int dailyDelayAllowance;
  final List<String> shiftStartTimes;
  final int shiftDuration;
  final int shiftZoneInterval;
  final int shiftEdgeTolerance;
  final int shiftInnerTolerance;
  final int shiftDurationTolerance;
  final int shiftBaselineHours;
  final int shiftCeilingHours;
  final String roundingMode;
  final int maxReportDateRange;

  String get dailyEndTime {
    final parts = dailyStartTime.split(':');
    final totalMinutes =
        int.parse(parts[0]) * 60 + int.parse(parts[1]) + dailyWorkDuration * 60;
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int get zoneCount => (shiftDuration ~/ shiftZoneInterval) + 1;

  // A zone's validity window must never reach outside its own bucket, or a
  // timestamp could satisfy one zone while belonging to a neighbour's bucket.
  // The narrowest bucket half-width is zone_interval / 2, so both tolerances
  // are capped there. Zone interval is in hours, tolerances in minutes.
  int get maxToleranceMinutes => shiftZoneInterval * 30;

  bool get hasValidTolerances =>
      shiftEdgeTolerance <= maxToleranceMinutes &&
      shiftInnerTolerance <= maxToleranceMinutes;

  AppSettings copyWith({
    String? dailyStartTime,
    int? dailyWorkDuration,
    int? dailyMaxOvertime,
    int? dailyDelayAllowance,
    List<String>? shiftStartTimes,
    int? shiftDuration,
    int? shiftZoneInterval,
    int? shiftEdgeTolerance,
    int? shiftInnerTolerance,
    int? shiftDurationTolerance,
    int? shiftBaselineHours,
    int? shiftCeilingHours,
    String? roundingMode,
    int? maxReportDateRange,
  }) {
    return AppSettings(
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyWorkDuration: dailyWorkDuration ?? this.dailyWorkDuration,
      dailyMaxOvertime: dailyMaxOvertime ?? this.dailyMaxOvertime,
      dailyDelayAllowance: dailyDelayAllowance ?? this.dailyDelayAllowance,
      shiftStartTimes: shiftStartTimes ?? this.shiftStartTimes,
      shiftDuration: shiftDuration ?? this.shiftDuration,
      shiftZoneInterval: shiftZoneInterval ?? this.shiftZoneInterval,
      shiftEdgeTolerance: shiftEdgeTolerance ?? this.shiftEdgeTolerance,
      shiftInnerTolerance: shiftInnerTolerance ?? this.shiftInnerTolerance,
      shiftDurationTolerance:
          shiftDurationTolerance ?? this.shiftDurationTolerance,
      shiftBaselineHours: shiftBaselineHours ?? this.shiftBaselineHours,
      shiftCeilingHours: shiftCeilingHours ?? this.shiftCeilingHours,
      roundingMode: roundingMode ?? this.roundingMode,
      maxReportDateRange: maxReportDateRange ?? this.maxReportDateRange,
    );
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      dailyStartTime: map['daily_start_time']!,
      dailyWorkDuration: int.parse(map['daily_work_duration']!),
      dailyMaxOvertime: int.parse(map['daily_max_overtime']!),
      dailyDelayAllowance: int.parse(map['daily_delay_allowance']!),
      shiftStartTimes: List<String>.from(
        jsonDecode(map['shift_start_times']!) as List,
      ),
      shiftDuration: int.parse(map['shift_duration']!),
      shiftZoneInterval: int.parse(map['shift_zone_interval']!),
      shiftEdgeTolerance: int.parse(map['shift_edge_tolerance']!),
      shiftInnerTolerance: int.parse(map['shift_inner_tolerance']!),
      shiftDurationTolerance: int.parse(map['shift_duration_tolerance']!),
      shiftBaselineHours: int.parse(map['shift_baseline_hours']!),
      shiftCeilingHours: int.parse(map['shift_ceiling_hours']!),
      roundingMode: map['rounding_mode']!,
      maxReportDateRange: int.tryParse(map['max_report_date_range'] ?? '') ?? 32,
    );
  }
}
