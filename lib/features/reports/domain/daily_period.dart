class DailyPeriod {
  DailyPeriod({
    required this.periodIndex,
    required this.date,
    required this.weekday,
    required this.dayType,
    required this.allTimestamps,
  });

  final int periodIndex;
  final String date; // ISO 8601
  final String weekday; // Arabic weekday name
  final String dayType; // 'regular' or 'off'
  final List<DateTime> allTimestamps;

  // Set by Stage 9 calculator
  int? totalAttendanceDuration;
  int? overtimeMinutes;
  bool? isValid;
  String? notes;
}
