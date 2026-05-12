import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  @visibleForTesting
  static void injectDatabase(Database db) => _database = db;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<void> init() async {
    _database = await _open();
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/overtime.db';
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
      // Ensures missing tables and seed rows are added even when the DB file
      // already exists (e.g. after a schema change during development).
      onOpen: (db) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_number TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        employment_type TEXT NOT NULL,
        department TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        occasion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_selected_employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        generation_datetime TEXT NOT NULL,
        range_start TEXT NOT NULL,
        range_end TEXT NOT NULL,
        total_employees INTEGER NOT NULL,
        total_shift_overtime_hours INTEGER NOT NULL,
        total_daily_overtime_minutes INTEGER NOT NULL,
        total_holiday_overtime_minutes INTEGER NOT NULL,
        unmatched_employee_count INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_employee_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
        employee_name TEXT NOT NULL,
        department TEXT NOT NULL,
        overtime_minutes INTEGER NOT NULL,
        holiday_overtime_minutes INTEGER NOT NULL,
        is_unmatched INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_period_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_result_id INTEGER NOT NULL REFERENCES daily_employee_results(id) ON DELETE CASCADE,
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_employee_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
        employee_name TEXT NOT NULL,
        department TEXT NOT NULL,
        overtime_hours INTEGER NOT NULL,
        is_unmatched INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_period_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_result_id INTEGER NOT NULL REFERENCES shift_employee_results(id) ON DELETE CASCADE,
        period_index INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        anchor_timestamp TEXT NOT NULL,
        all_timestamps TEXT NOT NULL,
        total_attendance_duration INTEGER NOT NULL,
        zone_data TEXT NOT NULL,
        hours_counted INTEGER NOT NULL,
        is_valid INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS column_headers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_type TEXT NOT NULL,
        field_key TEXT NOT NULL,
        header_value TEXT NOT NULL,
        is_default INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaults(Database db) async {
    final batch = db.batch();

    // app_settings defaults — INSERT OR IGNORE respects the UNIQUE constraint
    const settings = {
      'daily_start_time': '09:00',
      'daily_work_duration': '8',
      'daily_max_overtime': '3',
      'shift_start_times': '["08:00","11:00"]',
      'shift_duration': '24',
      'shift_zone_interval': '6',
      'shift_start_end_tolerance': '30',
      'shift_inner_tolerance': '60',
      'shift_period_gap': '6',
      'shift_baseline_hours': '154',
      'shift_ceiling_hours': '192',
      'rounding_mode': 'quarter',
      'max_report_date_range': '31',
    };

    for (final entry in settings.entries) {
      batch.rawInsert(
        'INSERT OR IGNORE INTO app_settings (key, value) VALUES (?, ?)',
        [entry.key, entry.value],
      );
    }

    await batch.commit(noResult: true);

    // Migrate shift_start_times from single-entry to dual-entry default.
    await db.execute(
      "UPDATE app_settings SET value = ? WHERE key = 'shift_start_times' AND value = ?",
      ['["08:00","11:00"]', '["08:00"]'],
    );

    // Remove obsolete employees/holidays file-type headers from any existing install.
    await db.delete('column_headers', where: "file_type IN ('employees', 'holidays')");

    // column_headers defaults — only seed when the table is empty so that
    // onOpen does not duplicate rows on subsequent launches.
    final countResult = await db
        .rawQuery('SELECT COUNT(*) AS c FROM column_headers WHERE is_default = 1');
    final alreadySeeded = (countResult.first['c'] as int) > 0;
    if (alreadySeeded) return;

    const headers = [
      ('attendance', 'employee_name', 'اسم الموظف'),
      ('attendance', 'datetime', 'التاريخ والوقت'),
    ];

    final headerBatch = db.batch();
    for (final (fileType, fieldKey, headerValue) in headers) {
      headerBatch.insert('column_headers', {
        'file_type': fileType,
        'field_key': fieldKey,
        'header_value': headerValue,
        'is_default': 1,
      });
    }
    await headerBatch.commit(noResult: true);
  }
}
