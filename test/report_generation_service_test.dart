import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reporting/application/report_generation_service.dart';
import 'package:overtime/shared/domain/attendance_record.dart';
import 'package:overtime/shared/domain/employee.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/db_test_helper.dart';

// buildDictionary is a pure function on ReportGenerationService.
// The DB is initialized only to satisfy the constructor's repository field —
// buildDictionary itself performs no database access.

void main() {
  late ReportGenerationService service;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await setupTestDatabase();
    service = ReportGenerationService();
  });

  DateTime dt(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime(year, month, day, hour, minute);

  final startDate = DateTime(2026, 5, 1);
  final endDate = DateTime(2026, 5, 31);

  Employee emp(String name, {EmploymentType type = EmploymentType.daily}) =>
      Employee(name: name, employmentType: type, department: 'HR');

  AttendanceRecord att(String name, List<DateTime> fingerprints) =>
      AttendanceRecord(employeeName: name, fingerprints: fingerprints);

  // ── Name matching ────────────────────────────────────────────────────────────

  group('ReportGenerationService.buildDictionary — name matching', () {
    test('attendance record for name not in target list is discarded', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [att('محمد', [dt(2026, 5, 4, 8, 0)])], // 'محمد' not in target
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched, isEmpty);
      expect(result.unmatched, hasLength(1));
      expect(result.unmatched.first.name, 'أحمد');
    });

    test('name matching is exact — trailing space causes a miss', () {
      // 'أحمد ' (with trailing space) does not match 'أحمد'.
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [att('أحمد ', [dt(2026, 5, 4, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched, isEmpty);
      expect(result.unmatched.first.name, 'أحمد');
    });

    test('employee with in-range timestamps is placed in matched, not unmatched', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [att('أحمد', [dt(2026, 5, 4, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched.containsKey('أحمد'), isTrue);
      expect(result.unmatched, isEmpty);
    });
  });

  // ── Date range filtering ─────────────────────────────────────────────────────

  group('ReportGenerationService.buildDictionary — date range filtering', () {
    test('employee with attendance only outside date range appears in unmatched', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [att('أحمد', [dt(2026, 4, 30, 8, 0)])], // April 30 — before range
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched, isEmpty);
      expect(result.unmatched.first.name, 'أحمد');
    });

    test('timestamps outside date range are filtered out from matched entries', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [
          att('أحمد', [
            dt(2026, 4, 30, 8, 0),  // before range → excluded
            dt(2026, 5, 4, 8, 0),   // in range → included
            dt(2026, 6, 1, 8, 0),   // after range → excluded
          ]),
        ],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched['أحمد']!.timestamps, hasLength(1));
      expect(result.matched['أحمد']!.timestamps.first, dt(2026, 5, 4, 8, 0));
    });

    test('timestamps on the start date are included', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [att('أحمد', [dt(2026, 5, 1, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched['أحمد']!.timestamps, hasLength(1));
    });

    test('timestamps on the end date are included', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [att('أحمد', [dt(2026, 5, 31, 23, 59)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched['أحمد']!.timestamps, hasLength(1));
    });
  });

  // ── Duplicate names ──────────────────────────────────────────────────────────

  group('ReportGenerationService.buildDictionary — duplicate employee names', () {
    test('duplicate employee names in target list: last row wins for metadata', () {
      // Two rows with the same name but different departments — last row must win.
      final employees = [
        Employee(name: 'أحمد', employmentType: EmploymentType.daily, department: 'IT'),
        Employee(name: 'أحمد', employmentType: EmploymentType.shift, department: 'HR'),
      ];

      final result = service.buildDictionary(
        employees: employees,
        attendance: [att('أحمد', [dt(2026, 5, 4, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched['أحمد']!.employee.department, 'HR');
      expect(result.matched['أحمد']!.employee.employmentType, EmploymentType.shift);
    });
  });

  // ── Multi-file merging ───────────────────────────────────────────────────────

  group('ReportGenerationService.buildDictionary — multi-file merging', () {
    test('timestamps from multiple attendance records for the same employee are merged', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [
          att('أحمد', [dt(2026, 5, 4, 8, 0)]),
          att('أحمد', [dt(2026, 5, 5, 8, 0)]),
        ],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched['أحمد']!.timestamps, hasLength(2));
    });

    test('merged timestamps are sorted ascending', () {
      // Supply records in reverse order — merged result must be sorted.
      final result = service.buildDictionary(
        employees: [emp('أحمد')],
        attendance: [
          att('أحمد', [dt(2026, 5, 5, 8, 0)]),
          att('أحمد', [dt(2026, 5, 4, 8, 0)]),
        ],
        startDate: startDate,
        endDate: endDate,
      );

      final ts = result.matched['أحمد']!.timestamps;
      expect(ts.first, dt(2026, 5, 4, 8, 0));
      expect(ts.last, dt(2026, 5, 5, 8, 0));
    });
  });

  // ── Unmatched detection ──────────────────────────────────────────────────────

  group('ReportGenerationService.buildDictionary — unmatched detection', () {
    test('employee in target list with no attendance entry is in unmatched list', () {
      final result = service.buildDictionary(
        employees: [emp('أحمد'), emp('علي')],
        attendance: [att('أحمد', [dt(2026, 5, 4, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.unmatched.map((e) => e.name), contains('علي'));
      expect(result.unmatched.map((e) => e.name), isNot(contains('أحمد')));
    });

    test('employee count in matched + unmatched equals target list length when names are unique', () {
      final employees = [emp('أحمد'), emp('علي'), emp('فاطمة')];
      final result = service.buildDictionary(
        employees: employees,
        attendance: [att('أحمد', [dt(2026, 5, 4, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.matched.length + result.unmatched.length, 3);
    });

    test('matched entry preserves employee employment type and department', () {
      final shiftEmp = Employee(
        name: 'فاطمة',
        employmentType: EmploymentType.shift,
        department: 'الأمن',
      );

      final result = service.buildDictionary(
        employees: [shiftEmp],
        attendance: [att('فاطمة', [dt(2026, 5, 4, 8, 0)])],
        startDate: startDate,
        endDate: endDate,
      );

      final entry = result.matched['فاطمة']!;
      expect(entry.employee.employmentType, EmploymentType.shift);
      expect(entry.employee.department, 'الأمن');
    });
  });
}
