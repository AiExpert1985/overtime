import 'day_type.dart';

class DailyPeriodDetail {
  final DateTime date;
  final String weekday;
  final DayType dayType;
  final List<DateTime> timestamps;
  final int totalAttendanceDuration;
  final int overtimeMinutes;
  final bool isValid;
  final String? notes;

  const DailyPeriodDetail({
    required this.date,
    required this.weekday,
    required this.dayType,
    required this.timestamps,
    required this.totalAttendanceDuration,
    required this.overtimeMinutes,
    required this.isValid,
    this.notes,
  });
}

class DailyEmployeeResult {
  final String name;
  final String department;
  final bool isUnmatched;
  final String? notes;
  final int totalRegularOvertimeMinutes;
  final int totalHolidayOvertimeMinutes;
  final List<DailyPeriodDetail> periods;

  const DailyEmployeeResult({
    required this.name,
    required this.department,
    required this.isUnmatched,
    this.notes,
    required this.totalRegularOvertimeMinutes,
    required this.totalHolidayOvertimeMinutes,
    required this.periods,
  });
}
