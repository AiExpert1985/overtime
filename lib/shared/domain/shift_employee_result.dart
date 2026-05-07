class ZoneResult {
  final DateTime centerTime;
  final List<DateTime> timestamps;
  final bool isSatisfied;

  const ZoneResult({
    required this.centerTime,
    required this.timestamps,
    required this.isSatisfied,
  });
}

class ShiftPeriodDetail {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime anchorTimestamp;
  final List<DateTime> timestamps;
  final int totalAttendanceDuration;
  final List<ZoneResult> zoneResults;
  final int hoursCounted;
  final bool isValid;
  final String? notes;

  const ShiftPeriodDetail({
    required this.startDate,
    required this.endDate,
    required this.anchorTimestamp,
    required this.timestamps,
    required this.totalAttendanceDuration,
    required this.zoneResults,
    required this.hoursCounted,
    required this.isValid,
    this.notes,
  });
}

class ShiftEmployeeResult {
  final String name;
  final String department;
  final bool isUnmatched;
  final String? notes;
  final int totalOvertimeHours;
  final List<ShiftPeriodDetail> periods;

  const ShiftEmployeeResult({
    required this.name,
    required this.department,
    required this.isUnmatched,
    this.notes,
    required this.totalOvertimeHours,
    required this.periods,
  });
}
