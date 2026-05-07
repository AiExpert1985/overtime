import 'day_type.dart';

class RawDailyPeriod {
  final DateTime date;
  final DayType dayType;
  final List<DateTime> timestamps;

  const RawDailyPeriod({
    required this.date,
    required this.dayType,
    required this.timestamps,
  });
}

class RawDailyEmployeePeriods {
  final String name;
  final String department;
  final List<RawDailyPeriod> periods;

  const RawDailyEmployeePeriods({
    required this.name,
    required this.department,
    required this.periods,
  });
}
