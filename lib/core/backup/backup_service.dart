import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database.dart';

/// Report-only backup and restore, layered entirely on top of the existing
/// database — no schema, repository, or pipeline code is touched. A backup
/// file is a standalone SQLite file holding just the report-related tables
/// (never settings, column headers, or login accounts), built with SQLite's
/// own ATTACH DATABASE so no manual (de)serialization is needed.
class BackupService {
  const BackupService(this._db);

  final Database _db;

  static const _reportTables = [
    'reports',
    'shift_employee_results',
    'shift_period_details',
    'daily_employee_results',
    'daily_period_details',
    'undetected_employee_results',
    'undetected_period_details',
  ];

  /// Writes a full snapshot of every report currently in the database to
  /// `<app support dir>/manual_backup/reports_yyyymmddhhmm.db` and returns
  /// the resulting path.
  Future<String> exportManualBackup() => _export('manual_backup');

  /// Same as [exportManualBackup] but writes to the `auto_backup` folder and
  /// swallows any failure — a backup problem must never surface as a
  /// generation failure, since the report itself has already been stored
  /// successfully by the time this runs.
  Future<void> exportAutoBackupSilently() async {
    try {
      await _export('auto_backup');
    } catch (_) {
      // Best-effort only — see doc comment above.
    }
  }

  Future<String> _export(String folderName) async {
    final dir = await _backupDir(folderName);
    final path = await _uniquePath(dir, 'reports_${_timestamp()}.db');

    await _db.execute("ATTACH DATABASE '${_escape(path)}' AS backup_dst");
    try {
      for (final table in _reportTables) {
        await _db.execute(
          'CREATE TABLE backup_dst.$table AS SELECT * FROM main.$table',
        );
      }
    } finally {
      await _db.execute('DETACH DATABASE backup_dst');
    }
    return path;
  }

  /// Merges every report in the backup file at [path] into the live
  /// database. A report already present — matched by generation datetime
  /// and date range — is skipped; everything else is inserted with its full
  /// employee/period tree under freshly generated ids. Existing reports,
  /// settings, column headers, and accounts are never touched.
  Future<BackupImportResult> importBackup(String path) async {
    await _db.execute("ATTACH DATABASE '${_escape(path)}' AS import_src");
    try {
      final marker = await _db.rawQuery(
        "SELECT name FROM import_src.sqlite_master "
        "WHERE type = 'table' AND name = 'reports'",
      );
      if (marker.isEmpty) throw const BackupFormatException();

      return await _db.transaction(_mergeReports);
    } finally {
      await _db.execute('DETACH DATABASE import_src');
    }
  }

  Future<BackupImportResult> _mergeReports(Transaction txn) async {
    final incoming = await txn.query(
      'import_src.reports',
      orderBy: 'range_start ASC',
    );

    var added = 0;
    var skipped = 0;
    for (final report in incoming) {
      final duplicate = await txn.query(
        'reports',
        where:
            'generation_datetime = ? AND range_start = ? AND range_end = ?',
        whereArgs: [
          report['generation_datetime'],
          report['range_start'],
          report['range_end'],
        ],
      );
      if (duplicate.isNotEmpty) {
        skipped++;
        continue;
      }

      final oldReportId = report['id'] as int;
      final newReportId = await txn.insert('reports', {
        'generation_datetime': report['generation_datetime'],
        'range_start': report['range_start'],
        'range_end': report['range_end'],
      });

      await _mergeShift(txn, oldReportId, newReportId);
      await _mergeDaily(txn, oldReportId, newReportId);
      await _mergeUndetected(txn, oldReportId, newReportId);
      added++;
    }
    return BackupImportResult(added: added, skipped: skipped);
  }

  // Each category below is merged in two batched round-trips (all employee
  // rows, then all their period rows keyed by the new employee ids) instead
  // of one round-trip per row — a real report can hold hundreds of
  // employees with dozens of periods each, and report storage itself hit a
  // multi-minute stall from exactly this pattern before it was batched.

  Future<void> _mergeShift(
    Transaction txn,
    int oldReportId,
    int newReportId,
  ) async {
    final employees = await txn.query(
      'import_src.shift_employee_results',
      where: 'report_id = ?',
      whereArgs: [oldReportId],
    );
    if (employees.isEmpty) return;

    final employeeBatch = txn.batch();
    for (final e in employees) {
      employeeBatch.insert('shift_employee_results', {
        'report_id': newReportId,
        'employee_name': e['employee_name'],
        'department': e['department'],
        'overtime_hours': e['overtime_hours'],
        'is_included': e['is_included'],
      });
    }
    final idMap = _idMap(employees, await employeeBatch.commit());

    final periods = await _childRows(
      txn,
      'import_src.shift_period_details',
      idMap.keys.toList(),
    );
    final periodBatch = txn.batch();
    for (final p in periods) {
      periodBatch.insert('shift_period_details', {
        'employee_result_id': idMap[p['employee_result_id'] as int],
        'period_index': p['period_index'],
        'period_date': p['period_date'],
        'end_date': p['end_date'],
        'all_timestamps': p['all_timestamps'],
        'total_attendance_duration': p['total_attendance_duration'],
        'zone_data': p['zone_data'],
        'hours_counted': p['hours_counted'],
        'is_valid': p['is_valid'],
        'notes': p['notes'],
      });
    }
    await periodBatch.commit(noResult: true);
  }

  Future<void> _mergeDaily(
    Transaction txn,
    int oldReportId,
    int newReportId,
  ) async {
    final employees = await txn.query(
      'import_src.daily_employee_results',
      where: 'report_id = ?',
      whereArgs: [oldReportId],
    );
    if (employees.isEmpty) return;

    final employeeBatch = txn.batch();
    for (final e in employees) {
      employeeBatch.insert('daily_employee_results', {
        'report_id': newReportId,
        'employee_name': e['employee_name'],
        'department': e['department'],
        'total_overtime_minutes': e['total_overtime_minutes'],
        'regular_overtime_minutes': e['regular_overtime_minutes'],
        'off_overtime_minutes': e['off_overtime_minutes'],
        'is_included': e['is_included'],
      });
    }
    final idMap = _idMap(employees, await employeeBatch.commit());

    final periods = await _childRows(
      txn,
      'import_src.daily_period_details',
      idMap.keys.toList(),
    );
    final periodBatch = txn.batch();
    for (final p in periods) {
      periodBatch.insert('daily_period_details', {
        'employee_result_id': idMap[p['employee_result_id'] as int],
        'period_index': p['period_index'],
        'date': p['date'],
        'weekday': p['weekday'],
        'day_type': p['day_type'],
        'all_timestamps': p['all_timestamps'],
        'total_attendance_duration': p['total_attendance_duration'],
        'overtime_minutes': p['overtime_minutes'],
        'is_valid': p['is_valid'],
        'notes': p['notes'],
      });
    }
    await periodBatch.commit(noResult: true);
  }

  Future<void> _mergeUndetected(
    Transaction txn,
    int oldReportId,
    int newReportId,
  ) async {
    final employees = await txn.query(
      'import_src.undetected_employee_results',
      where: 'report_id = ?',
      whereArgs: [oldReportId],
    );
    if (employees.isEmpty) return;

    final employeeBatch = txn.batch();
    for (final e in employees) {
      employeeBatch.insert('undetected_employee_results', {
        'report_id': newReportId,
        'employee_name': e['employee_name'],
        'department': e['department'],
        'failure_reason': e['failure_reason'],
      });
    }
    final idMap = _idMap(employees, await employeeBatch.commit());

    final periods = await _childRows(
      txn,
      'import_src.undetected_period_details',
      idMap.keys.toList(),
    );
    final periodBatch = txn.batch();
    for (final p in periods) {
      periodBatch.insert('undetected_period_details', {
        'employee_result_id': idMap[p['employee_result_id'] as int],
        'period_index': p['period_index'],
        'date': p['date'],
        'weekday': p['weekday'],
        'all_timestamps': p['all_timestamps'],
      });
    }
    await periodBatch.commit(noResult: true);
  }

  // ---- helpers ----

  /// Maps each source row's old id to the id it was just re-inserted under,
  /// in insertion order.
  Map<int, int> _idMap(List<Map<String, dynamic>> rows, List<Object?> newIds) {
    return {
      for (var i = 0; i < rows.length; i++)
        rows[i]['id'] as int: newIds[i] as int,
    };
  }

  /// Fetches every child row for a set of old employee-result ids in a
  /// single query instead of one query per employee.
  Future<List<Map<String, dynamic>>> _childRows(
    Transaction txn,
    String table,
    List<int> employeeResultIds,
  ) {
    if (employeeResultIds.isEmpty) return Future.value(const []);
    final placeholders = List.filled(employeeResultIds.length, '?').join(',');
    return txn.query(
      table,
      where: 'employee_result_id IN ($placeholders)',
      whereArgs: employeeResultIds,
    );
  }

  // Next to the running exe (not the hidden app-data folder) so backups are
  // easy to find and copy to a USB drive/another machine without digging
  // through AppData.
  Future<Directory> _backupDir(String folderName) async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final dir = Directory('${exeDir.path}/$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _uniquePath(Directory dir, String fileName) async {
    final path = '${dir.path}/$fileName';
    if (!await File(path).exists()) return path;

    final base = fileName.substring(0, fileName.length - '.db'.length);
    var i = 2;
    while (await File('${dir.path}/${base}_$i.db').exists()) {
      i++;
    }
    return '${dir.path}/${base}_$i.db';
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}';
  }

  String _escape(String path) => path.replaceAll("'", "''");
}

class BackupImportResult {
  const BackupImportResult({required this.added, required this.skipped});

  final int added;
  final int skipped;
}

class BackupFormatException implements Exception {
  const BackupFormatException();

  String get arabicMessage => 'الملف المحدد ليس ملف نسخة احتياطية صالحة';
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(dbProvider));
});
