import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/daily_employee_entry.dart';
import '../domain/daily_employee_row.dart';
import '../domain/notes_codec.dart';
import '../domain/report.dart';
import '../domain/shift_employee_entry.dart';
import '../domain/shift_employee_row.dart';
import '../domain/undetected_employee_row.dart';
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

      await _insertShiftEntries(txn, reportId, shiftEntries.values.toList());
      await _insertDailyEntries(txn, reportId, dailyEntries.values.toList());
      await _insertUndetectedEntries(txn, reportId, undetectedList);

      return reportId;
    });
  }

  // Each employee category below is inserted in two batched round-trips
  // (all employee rows, then all their period rows) instead of one awaited
  // insert per row. sqflite_common_ffi serializes every call through a
  // single worker isolate, so a real report — hundreds of employees with
  // dozens of periods each — previously held the transaction lock for
  // minutes doing thousands of sequential round-trips, stalling every other
  // database call (e.g. deleting an older report) queued behind it.

  Future<void> _insertShiftEntries(
    Transaction txn,
    int reportId,
    List<ShiftEmployeeEntry> entries,
  ) async {
    if (entries.isEmpty) return;

    final employeeBatch = txn.batch();
    for (final entry in entries) {
      employeeBatch.insert('shift_employee_results', {
        'report_id': reportId,
        'employee_name': entry.name,
        'department': entry.department,
        'overtime_hours': entry.overtimeMinutes!,
        'is_included': 0,
      });
    }
    final employeeIds = await employeeBatch.commit();

    final periodBatch = txn.batch();
    for (var i = 0; i < entries.length; i++) {
      final employeeId = employeeIds[i] as int;
      for (final period in entries[i].periods) {
        periodBatch.insert('shift_period_details', {
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
                      'windowStart': z.windowStart.toIso8601String(),
                      'windowEnd': z.windowEnd.toIso8601String(),
                      'timestamps': z.timestamps
                          .map((ts) => ts.toIso8601String())
                          .toList(),
                      'isSatisfied': z.isSatisfied,
                    })
                .toList(),
          ),
          'hours_counted': period.hoursCounted!,
          'is_valid': period.isValid! ? 1 : 0,
          'notes': encodeNotes(period.notes),
        });
      }
    }
    await periodBatch.commit(noResult: true);
  }

  Future<void> _insertDailyEntries(
    Transaction txn,
    int reportId,
    List<DailyEmployeeEntry> entries,
  ) async {
    if (entries.isEmpty) return;

    final employeeBatch = txn.batch();
    for (final entry in entries) {
      employeeBatch.insert('daily_employee_results', {
        'report_id': reportId,
        'employee_name': entry.name,
        'department': entry.department,
        'total_overtime_minutes': entry.totalOvertimeMinutes!,
        'regular_overtime_minutes': entry.regularOvertimeMinutes!,
        'off_overtime_minutes': entry.offOvertimeMinutes!,
        'is_included': 0,
      });
    }
    final employeeIds = await employeeBatch.commit();

    final periodBatch = txn.batch();
    for (var i = 0; i < entries.length; i++) {
      final employeeId = employeeIds[i] as int;
      for (final period in entries[i].periods) {
        periodBatch.insert('daily_period_details', {
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
          'notes': encodeNotes(period.notes),
        });
      }
    }
    await periodBatch.commit(noResult: true);
  }

  Future<void> _insertUndetectedEntries(
    Transaction txn,
    int reportId,
    List<UndetectedEntry> entries,
  ) async {
    if (entries.isEmpty) return;

    final employeeBatch = txn.batch();
    for (final entry in entries) {
      employeeBatch.insert('undetected_employee_results', {
        'report_id': reportId,
        'employee_name': entry.name,
        'department': entry.department,
        'failure_reason': entry.failureReason,
      });
    }
    final employeeIds = await employeeBatch.commit();

    final periodBatch = txn.batch();
    for (var i = 0; i < entries.length; i++) {
      final employeeId = employeeIds[i] as int;
      final dayMap = _groupByDay(entries[i].timestamps);
      final sortedKeys = dayMap.keys.toList()..sort();
      for (var j = 0; j < sortedKeys.length; j++) {
        final dateStr = sortedKeys[j];
        final dayTimestamps = dayMap[dateStr]!;
        periodBatch.insert('undetected_period_details', {
          'employee_result_id': employeeId,
          'period_index': j,
          'date': dateStr,
          'weekday': _arabicWeekdays[DateTime.parse(dateStr).weekday],
          'all_timestamps': jsonEncode(
            dayTimestamps.map((ts) => ts.toIso8601String()).toList(),
          ),
        });
      }
    }
    await periodBatch.commit(noResult: true);
  }

  Future<Report> loadReport(int id) async {
    final rows = await _db.query(
      'reports',
      columns: ['id', 'generation_datetime', 'range_start', 'range_end'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return Report.fromMap(rows.first);
  }

  Future<List<ShiftEmployeeRow>> loadShiftResults(int reportId) async {
    final rows = await _db.query(
      'shift_employee_results',
      columns: ['id', 'employee_name', 'department', 'overtime_hours', 'is_included'],
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    return rows.map(ShiftEmployeeRow.fromMap).toList();
  }

  Future<List<DailyEmployeeRow>> loadDailyResults(int reportId) async {
    final rows = await _db.query(
      'daily_employee_results',
      columns: [
        'id',
        'employee_name',
        'department',
        'total_overtime_minutes',
        'regular_overtime_minutes',
        'off_overtime_minutes',
        'is_included',
      ],
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    return rows.map(DailyEmployeeRow.fromMap).toList();
  }

  Future<List<UndetectedEmployeeRow>> loadUndetectedResults(int reportId) async {
    final rows = await _db.query(
      'undetected_employee_results',
      columns: ['id', 'employee_name', 'department', 'failure_reason'],
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    return rows.map(UndetectedEmployeeRow.fromMap).toList();
  }

  Future<void> setIsIncluded(int id, String table, bool value) async {
    await _db.update(
      table,
      {'is_included': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> loadShiftEmployeeResult(int id) async {
    final rows = await _db.query(
      'shift_employee_results',
      columns: ['employee_name', 'department', 'overtime_hours'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.first;
  }

  Future<Map<String, dynamic>> loadDailyEmployeeResult(int id) async {
    final rows = await _db.query(
      'daily_employee_results',
      columns: ['employee_name', 'department', 'total_overtime_minutes'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> loadShiftPeriods(int employeeResultId) async {
    return _db.query(
      'shift_period_details',
      where: 'employee_result_id = ?',
      whereArgs: [employeeResultId],
      orderBy: 'period_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> loadDailyPeriods(int employeeResultId) async {
    return _db.query(
      'daily_period_details',
      where: 'employee_result_id = ?',
      whereArgs: [employeeResultId],
      orderBy: 'period_index ASC',
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, List<DateTime>> _groupByDay(List<DateTime> timestamps) {
    final map = <String, List<DateTime>>{};
    for (final ts in timestamps) {
      final key =
          '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(ts);
    }
    return map;
  }

  static const _arabicWeekdays = [
    '',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  Future<Map<String, dynamic>> loadUndetectedEmployeeResult(int id) async {
    final rows = await _db.query(
      'undetected_employee_results',
      columns: ['employee_name', 'department', 'failure_reason'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> loadUndetectedPeriods(
      int employeeResultId) async {
    return _db.query(
      'undetected_period_details',
      where: 'employee_result_id = ?',
      whereArgs: [employeeResultId],
      orderBy: 'period_index ASC',
    );
  }
}
