import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:overtime/shared/database/database_helper.dart';

Database? _lastTestDb;

/// Opens a fresh in-memory SQLite database, creates the schema with seed data,
/// and injects it into [DatabaseHelper] for the duration of a test.
/// Closes the previous test database first to ensure full isolation.
/// Call in setUp().
Future<Database> setupTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await _lastTestDb?.close();
  _lastTestDb = null;

  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
    ),
  );

  _lastTestDb = db;
  DatabaseHelper.injectDatabase(db);
  return db;
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
  for (final e in settings.entries) {
    await db.rawInsert(
      'INSERT OR IGNORE INTO app_settings (key, value) VALUES (?, ?)',
      [e.key, e.value],
    );
  }

  const headers = [
    ('attendance', 'employee_name', 'اسم الموظف', 1),
    ('attendance', 'datetime', 'التاريخ والوقت', 1),
    ('employees', 'employee_name', 'اسم الموظف', 1),
    ('employees', 'employment_type', 'نوع التوظيف', 1),
    ('employees', 'department', 'القسم', 1),
    ('holidays', 'date', 'التاريخ', 1),
    ('holidays', 'occasion', 'مناسبة العطلة', 1),
  ];
  for (final (ft, fk, hv, isDefault) in headers) {
    await db.rawInsert(
      'INSERT OR IGNORE INTO column_headers (file_type, field_key, header_value, is_default) VALUES (?, ?, ?, ?)',
      [ft, fk, hv, isDefault],
    );
  }
}
