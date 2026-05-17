import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/daily_period_row.dart';
import '../domain/shift_period_row.dart';
import 'reports_provider.dart';

typedef DetailArgs = ({int reportId, int employeeResultId, String employeeType});

class DetailState {
  const DetailState({
    required this.employeeName,
    required this.department,
    required this.employeeType,
    required this.reportRangeStart,
    required this.reportRangeEnd,
    this.shiftPeriods = const [],
    this.dailyPeriods = const [],
    this.totalOvertimeMinutes = 0,
  });

  final String employeeName;
  final String department;
  final String employeeType;
  final DateTime reportRangeStart;
  final DateTime reportRangeEnd;
  final List<ShiftPeriodRow> shiftPeriods;
  final List<DailyPeriodRow> dailyPeriods;
  // Stored total for daily header; shift header recomputes live from periods.
  final int totalOvertimeMinutes;
}

class DetailNotifier extends AsyncNotifier<DetailState> {
  DetailNotifier(this._args);

  final DetailArgs _args;

  @override
  Future<DetailState> build() async {
    final repo = ref.read(reportsRepositoryProvider);
    final reportFuture = repo.loadReport(_args.reportId);

    if (_args.employeeType == 'shift') {
      final employeeFuture = repo.loadShiftEmployeeResult(_args.employeeResultId);
      final periodsFuture = repo.loadShiftPeriods(_args.employeeResultId);
      final report = await reportFuture;
      final employee = await employeeFuture;
      final rawPeriods = await periodsFuture;
      return DetailState(
        employeeName: employee['employee_name'] as String,
        department: employee['department'] as String,
        employeeType: 'shift',
        reportRangeStart: report.rangeStart,
        reportRangeEnd: report.rangeEnd,
        shiftPeriods: rawPeriods.map(ShiftPeriodRow.fromMap).toList(),
      );
    } else {
      final employeeFuture = repo.loadDailyEmployeeResult(_args.employeeResultId);
      final periodsFuture = repo.loadDailyPeriods(_args.employeeResultId);
      final report = await reportFuture;
      final employee = await employeeFuture;
      final rawPeriods = await periodsFuture;
      return DetailState(
        employeeName: employee['employee_name'] as String,
        department: employee['department'] as String,
        employeeType: 'daily',
        reportRangeStart: report.rangeStart,
        reportRangeEnd: report.rangeEnd,
        dailyPeriods: rawPeriods.map(DailyPeriodRow.fromMap).toList(),
        totalOvertimeMinutes: employee['total_overtime_minutes'] as int,
      );
    }
  }
}

final detailProvider =
    AsyncNotifierProvider.family<DetailNotifier, DetailState, DetailArgs>(
  DetailNotifier.new,
);
