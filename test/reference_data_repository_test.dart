import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reference_data/data/reference_data_repository.dart';
import 'package:overtime/shared/database/database_helper.dart';
import 'package:overtime/shared/domain/employee.dart';

import 'helpers/db_test_helper.dart';

void main() {
  late ReferenceDataRepository repo;

  setUp(() async {
    await setupTestDatabase();
    repo = ReferenceDataRepository(DatabaseHelper.instance);
  });

  // ── Employees ───────────────────────────────────────────────────────────────

  group('getAllEmployees', () {
    test('returns empty list when no employees exist', () async {
      expect(await repo.getAllEmployees(), isEmpty);
    });

    test('returns all employees ordered by name ascending', () async {
      await repo.addEmployee(
        employeeNumber: '002',
        name: 'محمد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );

      final employees = await repo.getAllEmployees();

      expect(employees.map((e) => e.name).toList(), equals(['أحمد', 'محمد']));
    });

    test('returned record contains all persisted fields', () async {
      await repo.addEmployee(
        employeeNumber: 'EMP-99',
        name: 'علي',
        employmentType: EmploymentType.shift,
        department: 'الصيانة',
      );

      final employee = (await repo.getAllEmployees()).first;

      expect(employee.employeeNumber, 'EMP-99');
      expect(employee.name, 'علي');
      expect(employee.employmentType, EmploymentType.shift);
      expect(employee.department, 'الصيانة');
    });
  });

  group('employeeNumberExists', () {
    test('returns false when number does not exist', () async {
      expect(await repo.employeeNumberExists('UNKNOWN'), isFalse);
    });

    test('returns true when number is already in use', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );

      expect(await repo.employeeNumberExists('001'), isTrue);
    });

    test('returns false for own number when excludeId is set — allows editing without false conflict', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      final id = (await repo.getAllEmployees()).first.id;

      expect(await repo.employeeNumberExists('001', excludeId: id), isFalse);
    });

    test('returns true when another employee holds the number, even with excludeId set', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      await repo.addEmployee(
        employeeNumber: '002',
        name: 'محمد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );
      final targetId = (await repo.getAllEmployees())
          .firstWhere((e) => e.employeeNumber == '002')
          .id;

      expect(await repo.employeeNumberExists('001', excludeId: targetId), isTrue);
    });
  });

  group('addEmployee', () {
    test('persists all fields and they round-trip correctly', () async {
      await repo.addEmployee(
        employeeNumber: 'EMP-01',
        name: 'خالد',
        employmentType: EmploymentType.daily,
        department: 'المالية',
      );

      final employees = await repo.getAllEmployees();
      expect(employees.length, 1);
      expect(employees.first.employeeNumber, 'EMP-01');
      expect(employees.first.name, 'خالد');
      expect(employees.first.employmentType, EmploymentType.daily);
      expect(employees.first.department, 'المالية');
    });

    test('employment_type round-trips for both shift and daily', () async {
      await repo.addEmployee(
        employeeNumber: 'S-01',
        name: 'سالم',
        employmentType: EmploymentType.shift,
        department: 'العمليات',
      );
      await repo.addEmployee(
        employeeNumber: 'D-01',
        name: 'داود',
        employmentType: EmploymentType.daily,
        department: 'العمليات',
      );

      final employees = await repo.getAllEmployees();
      final shift = employees.firstWhere((e) => e.employeeNumber == 'S-01');
      final daily = employees.firstWhere((e) => e.employeeNumber == 'D-01');

      expect(shift.employmentType, EmploymentType.shift);
      expect(daily.employmentType, EmploymentType.daily);
    });
  });

  group('updateEmployee', () {
    test('updates all fields for the target employee', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      final id = (await repo.getAllEmployees()).first.id;

      await repo.updateEmployee(
        id,
        employeeNumber: '001-B',
        name: 'أحمد الجديد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );

      final updated = (await repo.getAllEmployees()).first;
      expect(updated.employeeNumber, '001-B');
      expect(updated.name, 'أحمد الجديد');
      expect(updated.employmentType, EmploymentType.shift);
      expect(updated.department, 'الإنتاج');
    });

    test('does not affect other employees', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      await repo.addEmployee(
        employeeNumber: '002',
        name: 'محمد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );
      final targetId = (await repo.getAllEmployees())
          .firstWhere((e) => e.employeeNumber == '001')
          .id;

      await repo.updateEmployee(
        targetId,
        employeeNumber: '001-X',
        name: 'أحمد X',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );

      final other = (await repo.getAllEmployees())
          .firstWhere((e) => e.employeeNumber == '002');
      expect(other.name, 'محمد');
      expect(other.employmentType, EmploymentType.shift);
    });
  });

  group('deleteEmployee', () {
    test('removes the target employee', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      final id = (await repo.getAllEmployees()).first.id;

      await repo.deleteEmployee(id);

      expect(await repo.getAllEmployees(), isEmpty);
    });

    test('does not affect other employees', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      await repo.addEmployee(
        employeeNumber: '002',
        name: 'محمد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );
      final targetId = (await repo.getAllEmployees())
          .firstWhere((e) => e.employeeNumber == '001')
          .id;

      await repo.deleteEmployee(targetId);

      final remaining = await repo.getAllEmployees();
      expect(remaining.length, 1);
      expect(remaining.first.employeeNumber, '002');
    });

    test('cascade deletes the saved selection entry for the deleted employee', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      final id = (await repo.getAllEmployees()).first.id;
      await repo.saveSelectedEmployeeIds([id]);

      await repo.deleteEmployee(id);

      expect(await repo.getSelectedEmployeeIds(), isEmpty);
    });
  });

  // ── Holidays ───────────────────────────────────────────────────────────────

  group('getAllHolidays', () {
    test('returns empty list when no holidays exist', () async {
      expect(await repo.getAllHolidays(), isEmpty);
    });

    test('returns all holidays ordered by date ascending', () async {
      await repo.addHoliday(date: DateTime(2026, 3, 15), occasion: 'عطلة مارس');
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');

      final holidays = await repo.getAllHolidays();

      expect(holidays[0].occasion, 'رأس السنة');
      expect(holidays[1].occasion, 'عطلة مارس');
    });
  });

  group('addHoliday', () {
    test('persists all fields and they round-trip correctly', () async {
      await repo.addHoliday(date: DateTime(2026, 6, 20), occasion: 'عيد الفطر');

      final holiday = (await repo.getAllHolidays()).first;
      expect(holiday.date.year, 2026);
      expect(holiday.date.month, 6);
      expect(holiday.date.day, 20);
      expect(holiday.occasion, 'عيد الفطر');
    });

    test('date stored as ISO 8601 date-only — time component is stripped', () async {
      await repo.addHoliday(
        date: DateTime(2026, 6, 20, 15, 30, 45),
        occasion: 'عيد الفطر',
      );

      final holiday = (await repo.getAllHolidays()).first;
      expect(holiday.date.hour, 0);
      expect(holiday.date.minute, 0);
      expect(holiday.date.second, 0);
    });

    test('same date may be added more than once — no uniqueness enforced on date', () async {
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'إجازة إضافية');

      final holidays = await repo.getAllHolidays();
      expect(holidays.length, 2);
    });
  });

  group('updateHoliday', () {
    test('updates all fields for the target holiday', () async {
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');
      final id = (await repo.getAllHolidays()).first.id;

      await repo.updateHoliday(id, date: DateTime(2026, 12, 31), occasion: 'نهاية العام');

      final updated = (await repo.getAllHolidays()).first;
      expect(updated.date.month, 12);
      expect(updated.date.day, 31);
      expect(updated.occasion, 'نهاية العام');
    });

    test('date stored as ISO 8601 date-only after update — time component is stripped', () async {
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');
      final id = (await repo.getAllHolidays()).first.id;

      await repo.updateHoliday(
        id,
        date: DateTime(2026, 6, 15, 12, 30),
        occasion: 'إجازة صيفية',
      );

      final updated = (await repo.getAllHolidays()).first;
      expect(updated.date.hour, 0);
      expect(updated.date.minute, 0);
    });

    test('does not affect other holidays', () async {
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');
      await repo.addHoliday(date: DateTime(2026, 6, 1), occasion: 'عيد الفطر');
      final targetId = (await repo.getAllHolidays())
          .firstWhere((h) => h.occasion == 'رأس السنة')
          .id;

      await repo.updateHoliday(targetId, date: DateTime(2026, 1, 2), occasion: 'تعديل');

      final other = (await repo.getAllHolidays())
          .firstWhere((h) => h.occasion == 'عيد الفطر');
      expect(other.date.month, 6);
      expect(other.date.day, 1);
    });
  });

  group('deleteHoliday', () {
    test('removes the target holiday', () async {
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');
      final id = (await repo.getAllHolidays()).first.id;

      await repo.deleteHoliday(id);

      expect(await repo.getAllHolidays(), isEmpty);
    });

    test('does not affect other holidays', () async {
      await repo.addHoliday(date: DateTime(2026, 1, 1), occasion: 'رأس السنة');
      await repo.addHoliday(date: DateTime(2026, 6, 1), occasion: 'عيد الفطر');
      final targetId = (await repo.getAllHolidays())
          .firstWhere((h) => h.occasion == 'رأس السنة')
          .id;

      await repo.deleteHoliday(targetId);

      final remaining = await repo.getAllHolidays();
      expect(remaining.length, 1);
      expect(remaining.first.occasion, 'عيد الفطر');
    });
  });

  // ── Report Selected Employees ──────────────────────────────────────────────

  group('getSelectedEmployeeIds', () {
    test('returns empty list when no selection has been saved', () async {
      expect(await repo.getSelectedEmployeeIds(), isEmpty);
    });

    test('returns the IDs that were previously saved', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      await repo.addEmployee(
        employeeNumber: '002',
        name: 'محمد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );
      final ids = (await repo.getAllEmployees()).map((e) => e.id).toList();

      await repo.saveSelectedEmployeeIds(ids);

      expect(await repo.getSelectedEmployeeIds(), containsAll(ids));
    });
  });

  group('saveSelectedEmployeeIds', () {
    test('replaces previous selection entirely on re-call', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      await repo.addEmployee(
        employeeNumber: '002',
        name: 'محمد',
        employmentType: EmploymentType.shift,
        department: 'الإنتاج',
      );
      final employees = await repo.getAllEmployees();
      final firstId = employees[0].id;
      final secondId = employees[1].id;

      await repo.saveSelectedEmployeeIds([firstId]);
      await repo.saveSelectedEmployeeIds([secondId]);

      final saved = await repo.getSelectedEmployeeIds();
      expect(saved, equals([secondId]));
      expect(saved, isNot(contains(firstId)));
    });

    test('calling with empty list clears all saved IDs', () async {
      await repo.addEmployee(
        employeeNumber: '001',
        name: 'أحمد',
        employmentType: EmploymentType.daily,
        department: 'الإدارة',
      );
      final id = (await repo.getAllEmployees()).first.id;
      await repo.saveSelectedEmployeeIds([id]);

      await repo.saveSelectedEmployeeIds([]);

      expect(await repo.getSelectedEmployeeIds(), isEmpty);
    });
  });
}
