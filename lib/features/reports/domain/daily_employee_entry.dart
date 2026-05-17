import 'daily_period.dart';

class DailyEmployeeEntry {
  DailyEmployeeEntry({
    required this.name,
    required this.department,
    required this.timestamps,
  });

  final String name;
  final String department;
  final List<DateTime> timestamps;
  List<DailyPeriod> periods = [];
}
