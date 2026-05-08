import 'dart:convert';

import '../database/database_helper.dart';
import '../domain/daily_employee_result.dart';
import '../domain/day_type.dart';
import '../domain/report_data.dart';
import '../domain/shift_employee_result.dart';

class ReportRepository {
  final DatabaseHelper _db;

  const ReportRepository(this._db);

  Future<int> insertReport({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<DailyEmployeeResult> dailyResults,
    required List<ShiftEmployeeResult> shiftResults,
  }) async {
    final db = await _db.database;

    final totalEmployees = dailyResults.length + shiftResults.length;
    final totalShiftOvertimeHours =
        shiftResults.fold(0, (sum, r) => sum + r.totalOvertimeHours);
    final totalDailyOvertimeMinutes =
        dailyResults.fold(0, (sum, r) => sum + r.totalRegularOvertimeMinutes);
    final totalHolidayOvertimeMinutes =
        dailyResults.fold(0, (sum, r) => sum + r.totalHolidayOvertimeMinutes);
    final unmatchedCount = [
      ...dailyResults.where((r) => r.isUnmatched),
      ...shiftResults.where((r) => r.isUnmatched),
    ].length;

    late int reportId;

    await db.transaction((txn) async {
      reportId = await txn.insert('reports', {
        'generation_datetime': DateTime.now().toIso8601String(),
        'range_start': rangeStart.toIso8601String(),
        'range_end': rangeEnd.toIso8601String(),
        'total_employees': totalEmployees,
        'total_shift_overtime_hours': totalShiftOvertimeHours,
        'total_daily_overtime_minutes': totalDailyOvertimeMinutes,
        'total_holiday_overtime_minutes': totalHolidayOvertimeMinutes,
        'unmatched_employee_count': unmatchedCount,
      });

      for (final result in dailyResults) {
        final empId = await txn.insert('daily_employee_results', {
          'report_id': reportId,
          'employee_name': result.name,
          'department': result.department,
          'overtime_minutes': result.totalRegularOvertimeMinutes,
          'holiday_overtime_minutes': result.totalHolidayOvertimeMinutes,
          'is_unmatched': result.isUnmatched ? 1 : 0,
          'notes': result.notes,
        });

        for (int idx = 0; idx < result.periods.length; idx++) {
          final p = result.periods[idx];
          await txn.insert('daily_period_details', {
            'employee_result_id': empId,
            'period_index': idx,
            'date': p.date.toIso8601String(),
            'weekday': p.weekday,
            'day_type': p.dayType.name,
            'all_timestamps': jsonEncode(
                p.timestamps.map((t) => t.toIso8601String()).toList()),
            'total_attendance_duration': p.totalAttendanceDuration,
            'overtime_minutes': p.overtimeMinutes,
            'is_valid': p.isValid ? 1 : 0,
            'notes': p.notes,
          });
        }
      }

      for (final result in shiftResults) {
        final empId = await txn.insert('shift_employee_results', {
          'report_id': reportId,
          'employee_name': result.name,
          'department': result.department,
          'overtime_hours': result.totalOvertimeHours,
          'is_unmatched': result.isUnmatched ? 1 : 0,
          'notes': result.notes,
        });

        for (int idx = 0; idx < result.periods.length; idx++) {
          final p = result.periods[idx];
          final zoneData = jsonEncode(p.zoneResults
              .map((z) => {
                    'centerTime': z.centerTime.toIso8601String(),
                    'timestamps':
                        z.timestamps.map((t) => t.toIso8601String()).toList(),
                    'isSatisfied': z.isSatisfied,
                  })
              .toList());

          await txn.insert('shift_period_details', {
            'employee_result_id': empId,
            'period_index': idx,
            'start_date': p.startDate.toIso8601String(),
            'end_date': p.endDate.toIso8601String(),
            'anchor_timestamp': p.anchorTimestamp.toIso8601String(),
            'all_timestamps': jsonEncode(
                p.timestamps.map((t) => t.toIso8601String()).toList()),
            'total_attendance_duration': p.totalAttendanceDuration,
            'zone_data': zoneData,
            'hours_counted': p.hoursCounted,
            'is_valid': p.isValid ? 1 : 0,
            'notes': p.notes,
          });
        }
      }
    });

    return reportId;
  }

  Future<List<ReportListItem>> getReportList() async {
    final db = await _db.database;
    final rows =
        await db.query('reports', orderBy: 'generation_datetime DESC');
    return rows.map(ReportListItem.fromMap).toList();
  }

  Future<ReportData?> getReport(int id) async {
    final db = await _db.database;

    final reportRows =
        await db.query('reports', where: 'id = ?', whereArgs: [id]);
    if (reportRows.isEmpty) return null;

    final dailyResultRows = await db.query(
      'daily_employee_results',
      where: 'report_id = ?',
      whereArgs: [id],
    );
    final shiftResultRows = await db.query(
      'shift_employee_results',
      where: 'report_id = ?',
      whereArgs: [id],
    );

    final dailyResults = <DailyEmployeeResult>[];
    for (final row in dailyResultRows) {
      final empId = row['id'] as int;
      final periodRows = await db.query(
        'daily_period_details',
        where: 'employee_result_id = ?',
        whereArgs: [empId],
        orderBy: 'period_index ASC',
      );
      dailyResults.add(_buildDailyResult(row, periodRows));
    }

    final shiftResults = <ShiftEmployeeResult>[];
    for (final row in shiftResultRows) {
      final empId = row['id'] as int;
      final periodRows = await db.query(
        'shift_period_details',
        where: 'employee_result_id = ?',
        whereArgs: [empId],
        orderBy: 'period_index ASC',
      );
      shiftResults.add(_buildShiftResult(row, periodRows));
    }

    return ReportData(
      summary: ReportListItem.fromMap(reportRows.first),
      dailyResults: dailyResults,
      shiftResults: shiftResults,
    );
  }

  Future<void> deleteReport(int id) async {
    final db = await _db.database;
    await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }

  // ── builders ─────────────────────────────────────────────────────────────

  DailyEmployeeResult _buildDailyResult(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> periodRows,
  ) {
    final periods = periodRows.map((p) {
      final timestamps = (jsonDecode(p['all_timestamps'] as String) as List)
          .map((s) => DateTime.parse(s as String))
          .toList();
      return DailyPeriodDetail(
        date: DateTime.parse(p['date'] as String),
        weekday: p['weekday'] as String,
        dayType: DayType.values.byName(p['day_type'] as String),
        timestamps: timestamps,
        totalAttendanceDuration: p['total_attendance_duration'] as int,
        overtimeMinutes: p['overtime_minutes'] as int,
        isValid: (p['is_valid'] as int) == 1,
        notes: p['notes'] as String?,
      );
    }).toList();

    return DailyEmployeeResult(
      name: row['employee_name'] as String,
      department: row['department'] as String,
      isUnmatched: (row['is_unmatched'] as int) == 1,
      notes: row['notes'] as String?,
      totalRegularOvertimeMinutes: row['overtime_minutes'] as int,
      totalHolidayOvertimeMinutes: row['holiday_overtime_minutes'] as int,
      periods: periods,
    );
  }

  ShiftEmployeeResult _buildShiftResult(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> periodRows,
  ) {
    final periods = periodRows.map((p) {
      final timestamps = (jsonDecode(p['all_timestamps'] as String) as List)
          .map((s) => DateTime.parse(s as String))
          .toList();
      final zoneResults =
          (jsonDecode(p['zone_data'] as String) as List).map((z) {
        final zMap = z as Map<String, dynamic>;
        return ZoneResult(
          centerTime: DateTime.parse(zMap['centerTime'] as String),
          timestamps: (zMap['timestamps'] as List)
              .map((s) => DateTime.parse(s as String))
              .toList(),
          isSatisfied: zMap['isSatisfied'] as bool,
        );
      }).toList();

      return ShiftPeriodDetail(
        startDate: DateTime.parse(p['start_date'] as String),
        endDate: DateTime.parse(p['end_date'] as String),
        anchorTimestamp: DateTime.parse(p['anchor_timestamp'] as String),
        timestamps: timestamps,
        totalAttendanceDuration: p['total_attendance_duration'] as int,
        zoneResults: zoneResults,
        hoursCounted: p['hours_counted'] as int,
        isValid: (p['is_valid'] as int) == 1,
        notes: p['notes'] as String?,
      );
    }).toList();

    return ShiftEmployeeResult(
      name: row['employee_name'] as String,
      department: row['department'] as String,
      isUnmatched: (row['is_unmatched'] as int) == 1,
      notes: row['notes'] as String?,
      totalOvertimeHours: row['overtime_hours'] as int,
      periods: periods,
    );
  }
}
