import 'daily_employee_result.dart';
import 'shift_employee_result.dart';

class ReportListItem {
  final int id;
  final DateTime generationDatetime;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int totalEmployees;
  final int totalShiftOvertimeHours;
  final int totalDailyOvertimeMinutes;
  final int totalHolidayOvertimeMinutes;
  final int unmatchedEmployeeCount;

  const ReportListItem({
    required this.id,
    required this.generationDatetime,
    required this.rangeStart,
    required this.rangeEnd,
    required this.totalEmployees,
    required this.totalShiftOvertimeHours,
    required this.totalDailyOvertimeMinutes,
    required this.totalHolidayOvertimeMinutes,
    required this.unmatchedEmployeeCount,
  });

  factory ReportListItem.fromMap(Map<String, dynamic> map) => ReportListItem(
        id: map['id'] as int,
        generationDatetime:
            DateTime.parse(map['generation_datetime'] as String),
        rangeStart: DateTime.parse(map['range_start'] as String),
        rangeEnd: DateTime.parse(map['range_end'] as String),
        totalEmployees: map['total_employees'] as int,
        totalShiftOvertimeHours: map['total_shift_overtime_hours'] as int,
        totalDailyOvertimeMinutes: map['total_daily_overtime_minutes'] as int,
        totalHolidayOvertimeMinutes:
            map['total_holiday_overtime_minutes'] as int,
        unmatchedEmployeeCount: map['unmatched_employee_count'] as int,
      );
}

class ReportData {
  final ReportListItem summary;
  final List<DailyEmployeeResult> dailyResults;
  final List<ShiftEmployeeResult> shiftResults;

  const ReportData({
    required this.summary,
    required this.dailyResults,
    required this.shiftResults,
  });
}
