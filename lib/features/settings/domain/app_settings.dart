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
    required this.shiftTolerance,
    required this.shiftBaselineHours,
    required this.shiftCeilingHours,
    required this.roundingMode,
  });

  final String dailyStartTime;
  final int dailyWorkDuration;
  final int dailyMaxOvertime;
  final int dailyDelayAllowance;
  final List<String> shiftStartTimes;
  final int shiftDuration;
  final int shiftZoneInterval;
  final int shiftTolerance;
  final int shiftBaselineHours;
  final int shiftCeilingHours;
  final String roundingMode;

  String get dailyEndTime {
    final parts = dailyStartTime.split(':');
    final totalMinutes =
        int.parse(parts[0]) * 60 + int.parse(parts[1]) + dailyWorkDuration * 60;
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int get zoneCount => (shiftDuration ~/ shiftZoneInterval) + 1;

  AppSettings copyWith({
    String? dailyStartTime,
    int? dailyWorkDuration,
    int? dailyMaxOvertime,
    int? dailyDelayAllowance,
    List<String>? shiftStartTimes,
    int? shiftDuration,
    int? shiftZoneInterval,
    int? shiftTolerance,
    int? shiftBaselineHours,
    int? shiftCeilingHours,
    String? roundingMode,
  }) {
    return AppSettings(
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyWorkDuration: dailyWorkDuration ?? this.dailyWorkDuration,
      dailyMaxOvertime: dailyMaxOvertime ?? this.dailyMaxOvertime,
      dailyDelayAllowance: dailyDelayAllowance ?? this.dailyDelayAllowance,
      shiftStartTimes: shiftStartTimes ?? this.shiftStartTimes,
      shiftDuration: shiftDuration ?? this.shiftDuration,
      shiftZoneInterval: shiftZoneInterval ?? this.shiftZoneInterval,
      shiftTolerance: shiftTolerance ?? this.shiftTolerance,
      shiftBaselineHours: shiftBaselineHours ?? this.shiftBaselineHours,
      shiftCeilingHours: shiftCeilingHours ?? this.shiftCeilingHours,
      roundingMode: roundingMode ?? this.roundingMode,
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
      shiftTolerance: int.parse(map['shift_tolerance']!),
      shiftBaselineHours: int.parse(map['shift_baseline_hours']!),
      shiftCeilingHours: int.parse(map['shift_ceiling_hours']!),
      roundingMode: map['rounding_mode']!,
    );
  }
}
