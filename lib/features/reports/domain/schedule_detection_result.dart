import 'employee_entry.dart';
import 'shift_employee_entry.dart';
import 'undetected_entry.dart';

class ScheduleDetectionResult {
  const ScheduleDetectionResult({
    required this.shiftTable,
    required this.dailyTable,
    required this.undetectedList,
  });

  final Map<String, ShiftEmployeeEntry> shiftTable;
  final Map<String, EmployeeEntry> dailyTable;
  final List<UndetectedEntry> undetectedList;
}
