import 'daily_employee_row.dart';
import 'shift_employee_row.dart';
import 'undetected_employee_row.dart';

/// The three employee categories a report can classify someone into.
enum EmployeeType { shift, daily, undetected }

/// Read-only view over one row from any of the three type-specific row
/// lists, so the report screen can render and filter them as a single
/// merged list without duplicating each type's fields.
class UnifiedEmployeeRow {
  const UnifiedEmployeeRow.shift(ShiftEmployeeRow row)
      : type = EmployeeType.shift,
        shift = row,
        daily = null,
        undetected = null;

  const UnifiedEmployeeRow.daily(DailyEmployeeRow row)
      : type = EmployeeType.daily,
        shift = null,
        daily = row,
        undetected = null;

  const UnifiedEmployeeRow.undetected(UndetectedEmployeeRow row)
      : type = EmployeeType.undetected,
        shift = null,
        daily = null,
        undetected = row;

  final EmployeeType type;
  final ShiftEmployeeRow? shift;
  final DailyEmployeeRow? daily;
  final UndetectedEmployeeRow? undetected;

  int get id => switch (type) {
        EmployeeType.shift => shift!.id,
        EmployeeType.daily => daily!.id,
        EmployeeType.undetected => undetected!.id,
      };

  String get employeeName => switch (type) {
        EmployeeType.shift => shift!.employeeName,
        EmployeeType.daily => daily!.employeeName,
        EmployeeType.undetected => undetected!.employeeName,
      };

  String get department => switch (type) {
        EmployeeType.shift => shift!.department,
        EmployeeType.daily => daily!.department,
        EmployeeType.undetected => undetected!.department,
      };

  // Undetected employees are never included and never carry overtime — both
  // filter pairs (مشمول/غير مشمول, لديه/بدون وقت اضافي) treat them uniformly
  // as excluded/no-overtime with no per-type special-casing beyond this.
  bool get isIncluded => switch (type) {
        EmployeeType.shift => shift!.isIncluded,
        EmployeeType.daily => daily!.isIncluded,
        EmployeeType.undetected => false,
      };

  int get overtimeMinutes => switch (type) {
        EmployeeType.shift => shift!.overtimeMinutes,
        EmployeeType.daily => daily!.totalOvertimeMinutes,
        EmployeeType.undetected => 0,
      };
}
