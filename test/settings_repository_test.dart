import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/shared/data/settings_repository.dart';
import 'package:overtime/shared/database/database_helper.dart';

import 'helpers/db_test_helper.dart';

void main() {
  late SettingsRepository repo;

  setUp(() async {
    await setupTestDatabase();
    repo = SettingsRepository(DatabaseHelper.instance);
  });

  group('getString', () {
    test('returns defaultValue when key is absent', () async {
      expect(await repo.getString('nonexistent', defaultValue: 'fallback'), 'fallback');
    });

    test('returns stored value when key exists', () async {
      await repo.setValue('daily_start_time', '08:30');
      expect(await repo.getString('daily_start_time', defaultValue: '09:00'), '08:30');
    });
  });

  group('setValue', () {
    test('inserts a new key', () async {
      await repo.setValue('new_key', 'hello');
      expect(await repo.getString('new_key', defaultValue: ''), 'hello');
    });

    test('updates an existing key (upsert)', () async {
      await repo.setValue('daily_start_time', '07:00');
      await repo.setValue('daily_start_time', '10:00');
      expect(await repo.getString('daily_start_time', defaultValue: ''), '10:00');
    });
  });

  group('getInt', () {
    test('parses integer value correctly', () async {
      await repo.setValue('daily_work_duration', '10');
      expect(await repo.getInt('daily_work_duration', defaultValue: 8), 10);
    });

    test('returns defaultValue when stored value is not a valid integer', () async {
      await repo.setValue('bad_key', 'not_a_number');
      expect(await repo.getInt('bad_key', defaultValue: 42), 42);
    });
  });

  group('getShiftStartTimes', () {
    test('returns ["08:00","11:00"] as the seeded default (contracts.md)', () async {
      final times = await repo.getShiftStartTimes();
      expect(times, ['08:00', '11:00']);
    });

    test('returns stored list after setShiftStartTimes', () async {
      await repo.setShiftStartTimes(['06:00', '12:00', '18:00']);
      expect(await repo.getShiftStartTimes(), ['06:00', '12:00', '18:00']);
    });

    test('round-trips a single entry list', () async {
      await repo.setShiftStartTimes(['08:00']);
      expect(await repo.getShiftStartTimes(), ['08:00']);
    });
  });

  group('setShiftStartTimes', () {
    test('persists via JSON so getShiftStartTimes reads it back correctly', () async {
      await repo.setShiftStartTimes(['09:00', '15:00']);
      final raw = await repo.getString('shift_start_times', defaultValue: '');
      expect(raw, '["09:00","15:00"]');
    });
  });
}
