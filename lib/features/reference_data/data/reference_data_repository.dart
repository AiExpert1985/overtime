import '../../../shared/database/database_helper.dart';
import '../../../shared/domain/employee.dart';
import '../domain/employee_record.dart';
import '../domain/holiday_record.dart';

class ReferenceDataRepository {
  final DatabaseHelper _db;

  ReferenceDataRepository(this._db);

  // ── Employees ──────────────────────────────────────────────────────────────

  Future<List<EmployeeRecord>> getAllEmployees() async {
    final db = await _db.database;
    final rows = await db.query('employees', orderBy: 'name ASC');
    return rows.map(_rowToEmployee).toList();
  }

  Future<bool> employeeNumberExists(String number, {int? excludeId}) async {
    final db = await _db.database;
    final where = excludeId != null
        ? 'employee_number = ? AND id != ?'
        : 'employee_number = ?';
    final args =
        excludeId != null ? [number, excludeId] : [number];
    final rows = await db.query(
      'employees',
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addEmployee({
    required String employeeNumber,
    required String name,
    required EmploymentType employmentType,
    required String department,
  }) async {
    final db = await _db.database;
    await db.insert('employees', {
      'employee_number': employeeNumber,
      'name': name,
      'employment_type': employmentType.name,
      'department': department,
    });
  }

  Future<void> updateEmployee(
    int id, {
    required String employeeNumber,
    required String name,
    required EmploymentType employmentType,
    required String department,
  }) async {
    final db = await _db.database;
    await db.update(
      'employees',
      {
        'employee_number': employeeNumber,
        'name': name,
        'employment_type': employmentType.name,
        'department': department,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteEmployee(int id) async {
    final db = await _db.database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  EmployeeRecord _rowToEmployee(Map<String, Object?> row) {
    return EmployeeRecord(
      id: row['id'] as int,
      employeeNumber: row['employee_number'] as String,
      name: row['name'] as String,
      employmentType:
          EmploymentType.values.byName(row['employment_type'] as String),
      department: row['department'] as String,
    );
  }

  // ── Holidays ───────────────────────────────────────────────────────────────

  Future<List<HolidayRecord>> getAllHolidays() async {
    final db = await _db.database;
    final rows = await db.query('holidays', orderBy: 'date ASC');
    return rows.map(_rowToHoliday).toList();
  }

  Future<void> addHoliday({
    required DateTime date,
    required String occasion,
  }) async {
    final db = await _db.database;
    await db.insert('holidays', {
      'date': date.toIso8601String().substring(0, 10),
      'occasion': occasion,
    });
  }

  Future<void> updateHoliday(
    int id, {
    required DateTime date,
    required String occasion,
  }) async {
    final db = await _db.database;
    await db.update(
      'holidays',
      {
        'date': date.toIso8601String().substring(0, 10),
        'occasion': occasion,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteHoliday(int id) async {
    final db = await _db.database;
    await db.delete('holidays', where: 'id = ?', whereArgs: [id]);
  }

  HolidayRecord _rowToHoliday(Map<String, Object?> row) {
    return HolidayRecord(
      id: row['id'] as int,
      date: DateTime.parse(row['date'] as String),
      occasion: row['occasion'] as String,
    );
  }
}
