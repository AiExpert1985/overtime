import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/database/database_helper.dart';
import '../../../../shared/domain/employee.dart';
import '../../data/reference_data_repository.dart';
import '../../domain/employee_record.dart';
import '../../domain/holiday_record.dart';

// ── Employees ─────────────────────────────────────────────────────────────────

class EmployeesNotifier extends AsyncNotifier<List<EmployeeRecord>> {
  late final ReferenceDataRepository _repo;

  @override
  Future<List<EmployeeRecord>> build() async {
    _repo = ReferenceDataRepository(DatabaseHelper.instance);
    return _repo.getAllEmployees();
  }

  Future<String?> addEmployee({
    required String employeeNumber,
    required String name,
    required EmploymentType employmentType,
    required String department,
  }) async {
    final exists = await _repo.employeeNumberExists(employeeNumber);
    if (exists) return 'الرقم الوظيفي مستخدم بالفعل';

    await _repo.addEmployee(
      employeeNumber: employeeNumber,
      name: name,
      employmentType: employmentType,
      department: department,
    );
    state = AsyncData(await _repo.getAllEmployees());
    return null;
  }

  Future<String?> updateEmployee(
    int id, {
    required String employeeNumber,
    required String name,
    required EmploymentType employmentType,
    required String department,
  }) async {
    final exists =
        await _repo.employeeNumberExists(employeeNumber, excludeId: id);
    if (exists) return 'الرقم الوظيفي مستخدم بالفعل';

    await _repo.updateEmployee(
      id,
      employeeNumber: employeeNumber,
      name: name,
      employmentType: employmentType,
      department: department,
    );
    state = AsyncData(await _repo.getAllEmployees());
    return null;
  }

  Future<void> deleteEmployee(int id) async {
    await _repo.deleteEmployee(id);
    state = AsyncData(await _repo.getAllEmployees());
  }
}

final employeesProvider =
    AsyncNotifierProvider<EmployeesNotifier, List<EmployeeRecord>>(
        EmployeesNotifier.new);

// ── Holidays ──────────────────────────────────────────────────────────────────

class HolidaysNotifier extends AsyncNotifier<List<HolidayRecord>> {
  late final ReferenceDataRepository _repo;

  @override
  Future<List<HolidayRecord>> build() async {
    _repo = ReferenceDataRepository(DatabaseHelper.instance);
    return _repo.getAllHolidays();
  }

  Future<void> addHoliday({
    required DateTime date,
    required String occasion,
  }) async {
    await _repo.addHoliday(date: date, occasion: occasion);
    state = AsyncData(await _repo.getAllHolidays());
  }

  Future<void> updateHoliday(
    int id, {
    required DateTime date,
    required String occasion,
  }) async {
    await _repo.updateHoliday(id, date: date, occasion: occasion);
    state = AsyncData(await _repo.getAllHolidays());
  }

  Future<void> deleteHoliday(int id) async {
    await _repo.deleteHoliday(id);
    state = AsyncData(await _repo.getAllHolidays());
  }
}

final holidaysProvider =
    AsyncNotifierProvider<HolidaysNotifier, List<HolidayRecord>>(
        HolidaysNotifier.new);
