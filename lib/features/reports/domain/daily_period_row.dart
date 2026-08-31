import 'dart:convert';

import 'notes_codec.dart';

class DailyPeriodRow {
  const DailyPeriodRow({
    required this.periodIndex,
    required this.date,
    required this.weekday,
    required this.dayType,
    required this.timestamps,
    required this.totalAttendanceDuration,
    required this.overtimeMinutes,
    required this.isValid,
    required this.notes,
  });

  final int periodIndex;
  final String date;
  final String weekday;
  final String dayType;
  final List<DateTime> timestamps;
  final int totalAttendanceDuration;
  final int overtimeMinutes;
  final bool isValid;
  final List<String> notes;

  factory DailyPeriodRow.fromMap(Map<String, dynamic> map) {
    final tsJson =
        jsonDecode(map['all_timestamps'] as String) as List<dynamic>;
    return DailyPeriodRow(
      periodIndex: map['period_index'] as int,
      date: map['date'] as String,
      weekday: map['weekday'] as String,
      dayType: map['day_type'] as String,
      timestamps:
          tsJson.map((ts) => DateTime.parse(ts as String)).toList(),
      totalAttendanceDuration: map['total_attendance_duration'] as int,
      overtimeMinutes: map['overtime_minutes'] as int,
      isValid: (map['is_valid'] as int) == 1,
      notes: decodeNotes(map['notes'] as String?),
    );
  }
}
