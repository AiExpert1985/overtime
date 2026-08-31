import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _schemaVersion = 6;

final dbProvider = Provider<Database>((ref) {
  throw UnimplementedError('dbProvider must be overridden in main');
});

class AppDatabase {
  static Future<Database> open() async {
    final appDir = await getApplicationSupportDirectory();
    final dbPath = '${appDir.path}/overtime.db';

    return openDatabase(
      dbPath,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS undetected_period_details (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_result_id INTEGER NOT NULL
                REFERENCES undetected_employee_results(id) ON DELETE CASCADE,
              period_index INTEGER NOT NULL,
              date TEXT NOT NULL,
              weekday TEXT NOT NULL,
              all_timestamps TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE daily_employee_results ADD COLUMN regular_overtime_minutes INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE daily_employee_results ADD COLUMN off_overtime_minutes INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "UPDATE app_settings SET value = '90' WHERE key = 'shift_tolerance' AND value = '60'",
          );
        }
        if (oldVersion < 5) {
          // shift_tolerance is split into an edge and an inner value, and a
          // period duration check is added. The settings rows must be
          // reshaped here or AppSettings.fromMap throws on the missing keys.
          await db.delete(
            'app_settings',
            where: 'key = ?',
            whereArgs: ['shift_tolerance'],
          );
          // Seeding only runs on create, so the three replacement keys must be
          // inserted here as well.
          await _seedAppSettings(db);
          // Stored periods carry the old single-string notes and zone data
          // without a validity window — neither is readable under the new
          // shape. The app has no production data, so old reports are dropped
          // rather than migrated (details cascade).
          await db.delete('reports');
        }
        if (oldVersion < 6) {
          // A build outside this repo's history also shipped schema version 5,
          // with a different settings vocabulary (shift_allowed_before_entry,
          // shift_zone_tolerance, and so on). Such a database matches the
          // version this code expects while holding keys it never defines and
          // lacking ones it requires, so the settings table is reconciled
          // against the current defaults rather than assumed to have any
          // particular prior shape.
          await _reconcileAppSettings(db);
          // Stored periods from any earlier vocabulary carry notes and zone
          // data in shapes this code cannot read. There is no production data,
          // so old reports are dropped rather than migrated (details cascade).
          await db.delete('reports');
        }
      },
      onOpen: (db) async {
        // Safety net: a missing settings key has a known default and is not an
        // error worth crashing on, but it would otherwise surface as an opaque
        // failure much later, during report generation.
        await _seedAppSettings(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        generation_datetime TEXT NOT NULL,
        range_start TEXT NOT NULL,
        range_end TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS shift_employee_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
        employee_name TEXT NOT NULL,
        department TEXT NOT NULL,
        overtime_hours INTEGER NOT NULL,
        is_included INTEGER NOT NULL DEFAULT 1
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS shift_period_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_result_id INTEGER NOT NULL
          REFERENCES shift_employee_results(id) ON DELETE CASCADE,
        period_index INTEGER NOT NULL,
        period_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        all_timestamps TEXT NOT NULL,
        total_attendance_duration INTEGER NOT NULL,
        zone_data TEXT NOT NULL,
        hours_counted INTEGER NOT NULL,
        is_valid INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS daily_employee_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
        employee_name TEXT NOT NULL,
        department TEXT NOT NULL,
        total_overtime_minutes INTEGER NOT NULL,
        regular_overtime_minutes INTEGER NOT NULL,
        off_overtime_minutes INTEGER NOT NULL,
        is_included INTEGER NOT NULL DEFAULT 1
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS daily_period_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_result_id INTEGER NOT NULL
          REFERENCES daily_employee_results(id) ON DELETE CASCADE,
        period_index INTEGER NOT NULL,
        date TEXT NOT NULL,
        weekday TEXT NOT NULL,
        day_type TEXT NOT NULL,
        all_timestamps TEXT NOT NULL,
        total_attendance_duration INTEGER NOT NULL,
        overtime_minutes INTEGER NOT NULL,
        is_valid INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS undetected_employee_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
        employee_name TEXT NOT NULL,
        department TEXT NOT NULL,
        failure_reason TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS undetected_period_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_result_id INTEGER NOT NULL
          REFERENCES undetected_employee_results(id) ON DELETE CASCADE,
        period_index INTEGER NOT NULL,
        date TEXT NOT NULL,
        weekday TEXT NOT NULL,
        all_timestamps TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS column_headers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_type TEXT NOT NULL,
        field_key TEXT NOT NULL,
        header_value TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  static Future<void> _seedDefaults(Database db) async {
    await _seedColumnHeaders(db);
    await _seedAppSettings(db);
  }

  static Future<void> _seedColumnHeaders(Database db) async {
    final defaults = [
      ('attendance', 'employee_name', 'اسم الموظف'),
      ('attendance', 'department', 'القسم'),
      ('attendance', 'datetime', 'التاريخ والوقت'),
    ];

    for (final (fileType, fieldKey, headerValue) in defaults) {
      final existing = await db.query(
        'column_headers',
        where: 'file_type = ? AND field_key = ? AND header_value = ?',
        whereArgs: [fileType, fieldKey, headerValue],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('column_headers', {
          'file_type': fileType,
          'field_key': fieldKey,
          'header_value': headerValue,
          'is_default': 1,
        });
      }
    }
  }

  static Map<String, String> get _settingsDefaults => {
      'daily_start_time': '08:00',
      'daily_work_duration': '8',
      'daily_max_overtime': '3',
      'daily_delay_allowance': '60',
      'shift_start_times': jsonEncode(['08:00']),
      'shift_duration': '24',
      'shift_zone_interval': '6',
      'shift_edge_tolerance': '30',
      'shift_inner_tolerance': '120',
      'shift_duration_tolerance': '60',
      'shift_baseline_hours': '154',
      'shift_ceiling_hours': '192',
      'rounding_mode': 'quarter',
      'max_report_date_range': '32',
    };

  // Drops settings keys this code does not define, then seeds any that are
  // missing. User-set values for keys that are still valid are left untouched.
  static Future<void> _reconcileAppSettings(Database db) async {
    final known = _settingsDefaults.keys.toSet();
    final rows = await db.query('app_settings', columns: ['key']);
    for (final row in rows) {
      final key = row['key'] as String;
      if (!known.contains(key)) {
        await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      }
    }
    await _seedAppSettings(db);
  }

  static Future<void> _seedAppSettings(Database db) async {
    for (final entry in _settingsDefaults.entries) {
      final existing = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [entry.key],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('app_settings', {
          'key': entry.key,
          'value': entry.value,
        });
      }
    }
  }
}
