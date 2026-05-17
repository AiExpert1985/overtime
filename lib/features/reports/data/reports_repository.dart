import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/daily_employee_entry.dart';
import '../domain/report.dart';
import '../domain/shift_employee_entry.dart';
import '../domain/undetected_entry.dart';

class ReportsRepository {
  const ReportsRepository(this._db);

  final Database _db;

  Future<List<Report>> loadReports() async {
    final rows = await _db.query(
      'reports',
      columns: ['id', 'generation_datetime', 'range_start', 'range_end'],
      orderBy: 'generation_datetime DESC',
    );
    return rows.map(Report.fromMap).toList();
  }

  Future<void> deleteReport(int id) async {
    await _db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> storeReport({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Map<String, ShiftEmployeeEntry> shiftEntries,
    required Map<String, DailyEmployeeEntry> dailyEntries,
    required List<UndetectedEntry> undetectedList,
  }) async {
    return await _db.transaction((txn) async {
      final reportId = await txn.insert('reports', {
        'generation_datetime': DateTime.now().toIso8601String(),
        'range_start': _isoDate(rangeStart),
        'range_end': _isoDate(rangeEnd),
      });

      for (final entry in shiftEntries.values) {
        final employeeId = await txn.insert('shift_employee_results', {
          'report_id': reportId,
          'employee_name': entry.name,
          'department': entry.department,
          'overtime_hours': entry.overtimeMinutes!,
          'is_included': 1,
        });

        for (final period in entry.periods) {
          await txn.insert('shift_period_details', {
            'employee_result_id': employeeId,
            'period_index': period.periodIndex,
            'period_date': period.periodDate,
            'end_date': period.endDate!,
            'all_timestamps': jsonEncode(
              period.allTimestamps.map((ts) => ts.toIso8601String()).toList(),
            ),
            'total_attendance_duration': period.totalAttendanceDuration!,
            'zone_data': jsonEncode(
              period.zoneResults
                  .map((z) => {
                        'zoneIndex': z.zoneIndex,
                        'startTime': z.startTime.toIso8601String(),
                        'endTime': z.endTime.toIso8601String(),
                        'timestamps': z.timestamps
                            .map((ts) => ts.toIso8601String())
                            .toList(),
                        'isSatisfied': z.isSatisfied,
                      })
                  .toList(),
            ),
            'hours_counted': period.hoursCounted!,
            'is_valid': period.isValid! ? 1 : 0,
            'notes': period.notes,
          });
        }
      }

      for (final entry in dailyEntries.values) {
        final employeeId = await txn.insert('daily_employee_results', {
          'report_id': reportId,
          'employee_name': entry.name,
          'department': entry.department,
          'total_overtime_minutes': entry.totalOvertimeMinutes!,
          'is_included': 1,
        });

        for (final period in entry.periods) {
          await txn.insert('daily_period_details', {
            'employee_result_id': employeeId,
            'period_index': period.periodIndex,
            'date': period.date,
            'weekday': period.weekday,
            'day_type': period.dayType,
            'all_timestamps': jsonEncode(
              period.allTimestamps.map((ts) => ts.toIso8601String()).toList(),
            ),
            'total_attendance_duration': period.totalAttendanceDuration!,
            'overtime_minutes': period.overtimeMinutes!,
            'is_valid': period.isValid! ? 1 : 0,
            'notes': period.notes,
          });
        }
      }

      for (final entry in undetectedList) {
        await txn.insert('undetected_employee_results', {
          'report_id': reportId,
          'employee_name': entry.name,
          'department': entry.department,
          'failure_reason': entry.failureReason,
        });
      }

      return reportId;
    });
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
