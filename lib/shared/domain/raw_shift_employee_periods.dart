class RawShiftPeriod {
  final DateTime anchorTimestamp;
  final List<DateTime> timestamps;

  const RawShiftPeriod({
    required this.anchorTimestamp,
    required this.timestamps,
  });
}

class RawShiftEmployeePeriods {
  final String name;
  final String department;
  final List<RawShiftPeriod> periods;

  const RawShiftEmployeePeriods({
    required this.name,
    required this.department,
    required this.periods,
  });
}
