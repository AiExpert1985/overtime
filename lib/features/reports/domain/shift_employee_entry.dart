import 'shift_period.dart';

class ShiftEmployeeEntry {
  ShiftEmployeeEntry({
    required this.name,
    required this.department,
    required this.detectedShiftStartTime,
    required this.timestamps,
  });

  final String name;
  final String department;
  final String detectedShiftStartTime; // e.g. "08:00"
  final List<DateTime> timestamps;
  List<ShiftPeriod> periods = [];
  int? overtimeMinutes; // Set by Stage 8
}
