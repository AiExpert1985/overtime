import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/shared/data/column_headers_repository.dart';
import 'package:overtime/shared/database/database_helper.dart';

import 'helpers/db_test_helper.dart';

void main() {
  late ColumnHeadersRepository repo;

  setUp(() async {
    await setupTestDatabase();
    repo = ColumnHeadersRepository(DatabaseHelper.instance);
  });

  group('getHeadersForFileType', () {
    test('returns seeded default headers grouped by field key', () async {
      final headers = await repo.getHeadersForFileType('attendance');
      expect(headers['employee_name'], contains('اسم الموظف'));
      expect(headers['datetime'], contains('التاريخ والوقت'));
    });

    test('returns empty map for unknown file type', () async {
      expect(await repo.getHeadersForFileType('unknown'), isEmpty);
    });
  });

  group('headerValueExists', () {
    test('returns true for seeded default value', () async {
      expect(
        await repo.headerValueExists('attendance', 'employee_name', 'اسم الموظف'),
        isTrue,
      );
    });

    test('returns false for value that does not exist', () async {
      expect(
        await repo.headerValueExists('attendance', 'employee_name', 'قيمة غير موجودة'),
        isFalse,
      );
    });
  });

  group('addHeader', () {
    test('adds a user-defined header and it appears in getHeadersForFileType', () async {
      await repo.addHeader('attendance', 'employee_name', 'الموظف');
      final headers = await repo.getHeadersForFileType('attendance');
      expect(headers['employee_name'], contains('الموظف'));
    });

    test('added header has is_default = false', () async {
      await repo.addHeader('attendance', 'employee_name', 'الموظف');
      final all = await repo.getAllHeaders();
      final added = all['attendance']!['employee_name']!
          .firstWhere((h) => h.headerValue == 'الموظف');
      expect(added.isDefault, isFalse);
    });
  });

  group('updateHeader', () {
    test('allows updating a header to its current value (no false uniqueness error)', () async {
      await repo.addHeader('attendance', 'employee_name', 'الموظف');
      final all = await repo.getAllHeaders();
      final id = all['attendance']!['employee_name']!
          .firstWhere((h) => !h.isDefault)
          .id;

      await repo.updateHeader(id, 'الموظف');

      final after = await repo.getAllHeaders();
      final values = after['attendance']!['employee_name']!.map((h) => h.headerValue);
      expect(values, contains('الموظف'));
    });

    test('updates value of a non-default header', () async {
      await repo.addHeader('attendance', 'employee_name', 'الموظف');
      final all = await repo.getAllHeaders();
      final id = all['attendance']!['employee_name']!
          .firstWhere((h) => !h.isDefault)
          .id;

      await repo.updateHeader(id, 'اسم الشخص');

      final updated = await repo.getAllHeaders();
      final values = updated['attendance']!['employee_name']!.map((h) => h.headerValue);
      expect(values, contains('اسم الشخص'));
      expect(values, isNot(contains('الموظف')));
    });

    test('does not update a default header (is_default guard)', () async {
      final all = await repo.getAllHeaders();
      final defaultItem = all['attendance']!['employee_name']!
          .firstWhere((h) => h.isDefault);

      await repo.updateHeader(defaultItem.id, 'قيمة جديدة');

      final after = await repo.getAllHeaders();
      final values = after['attendance']!['employee_name']!.map((h) => h.headerValue);
      expect(values, contains('اسم الموظف'));
      expect(values, isNot(contains('قيمة جديدة')));
    });
  });

  group('deleteHeader', () {
    test('removes a non-default header', () async {
      await repo.addHeader('attendance', 'employee_name', 'الموظف');
      final all = await repo.getAllHeaders();
      final id = all['attendance']!['employee_name']!
          .firstWhere((h) => !h.isDefault)
          .id;

      await repo.deleteHeader(id);

      final after = await repo.getAllHeaders();
      final values = after['attendance']!['employee_name']!.map((h) => h.headerValue);
      expect(values, isNot(contains('الموظف')));
    });

    test('does not delete a default header (is_default guard)', () async {
      final all = await repo.getAllHeaders();
      final defaultItem = all['attendance']!['employee_name']!
          .firstWhere((h) => h.isDefault);

      await repo.deleteHeader(defaultItem.id);

      final after = await repo.getAllHeaders();
      final values = after['attendance']!['employee_name']!.map((h) => h.headerValue);
      expect(values, contains('اسم الموظف'));
    });
  });

  group('getAllHeaders', () {
    test('returns all three file types with their default field keys', () async {
      final all = await repo.getAllHeaders();
      expect(all.keys, containsAll(['attendance', 'employees', 'holidays']));
      expect(all['employees']!.keys, containsAll(['employee_name', 'employment_type', 'department']));
      expect(all['holidays']!.keys, containsAll(['date', 'occasion']));
    });
  });
}
