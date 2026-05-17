import 'zone_row.dart';

class ShiftPeriodRow {
  const ShiftPeriodRow({
    required this.periodIndex,
    required this.periodDate,
    required this.endDate,
    required this.zoneResults,
    required this.totalAttendanceDuration,
    required this.hoursCounted,
    required this.isValid,
    this.notes,
  });

  final int periodIndex;
  final String periodDate;
  final String endDate;
  final List<ZoneRow> zoneResults;
  final int totalAttendanceDuration;
  final int hoursCounted;
  final bool isValid;
  final String? notes;

  factory ShiftPeriodRow.fromMap(Map<String, dynamic> map) => ShiftPeriodRow(
        periodIndex: map['period_index'] as int,
        periodDate: map['period_date'] as String,
        endDate: map['end_date'] as String,
        zoneResults: ZoneRow.listFromJson(map['zone_data'] as String),
        totalAttendanceDuration: map['total_attendance_duration'] as int,
        hoursCounted: map['hours_counted'] as int,
        isValid: (map['is_valid'] as int) == 1,
        notes: map['notes'] as String?,
      );
}
