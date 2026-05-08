import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reporting/application/shift_period_extractor.dart';
import 'package:overtime/shared/domain/employee.dart';

void main() {
  final extractor = ShiftPeriodExtractor();

  // Default settings from config.md: start=08:00, 24h shift, ±30 start/end tolerance, 6h gap.
  const settings = ShiftExtractorSettings(
    startTimes: ['08:00'],
    shiftDurationHours: 24,
    startEndToleranceMinutes: 30,
    periodGapHours: 6,
  );

  const employee = Employee(
    name: 'محمود',
    employmentType: EmploymentType.shift,
    department: 'الحراسة',
  );

  DateTime dt(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime(year, month, day, hour, minute);

  // ── Empty / no match ─────────────────────────────────────────────────────────

  group('ShiftPeriodExtractor.extract — empty / no match', () {
    test('returns empty periods for empty timestamp list', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [],
        settings: settings,
      );
      expect(result.periods, isEmpty);
    });

    test('returns empty periods when no timestamp matches any configured start time', () {
      // All timestamps at noon — nothing within ±30 min of 08:00.
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 12, 0), dt(2026, 5, 4, 18, 0)],
        settings: settings,
      );
      expect(result.periods, isEmpty);
    });
  });

  // ── Anchor detection ─────────────────────────────────────────────────────────

  group('ShiftPeriodExtractor.extract — anchor detection', () {
    test('detects anchor at first timestamp within tolerance of a configured start time', () {
      // 07:50 is within ±30 min of 08:00 → becomes anchor.
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 7, 50), dt(2026, 5, 4, 14, 0)],
        settings: settings,
      );

      expect(result.periods, hasLength(1));
      expect(result.periods.first.anchorTimestamp, dt(2026, 5, 4, 7, 50));
    });

    test('timestamps before the first matching start time are skipped', () {
      // 06:00 is outside ±30 of 08:00 → skipped. 08:05 matches → anchor.
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 6, 0), dt(2026, 5, 4, 8, 5), dt(2026, 5, 4, 14, 0)],
        settings: settings,
      );

      expect(result.periods.first.anchorTimestamp, dt(2026, 5, 4, 8, 5));
    });

    test('detects start time among multiple configured start times', () {
      const multiSettings = ShiftExtractorSettings(
        startTimes: ['08:00', '11:00'],
        shiftDurationHours: 24,
        startEndToleranceMinutes: 30,
        periodGapHours: 6,
      );
      // First timestamp matches 11:00, not 08:00.
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 11, 10), dt(2026, 5, 4, 18, 0)],
        settings: multiSettings,
      );

      expect(result.periods, hasLength(1));
      expect(result.periods.first.anchorTimestamp, dt(2026, 5, 4, 11, 10));
    });
  });

  // ── Period span ──────────────────────────────────────────────────────────────

  group('ShiftPeriodExtractor.extract — period span', () {
    test('all timestamps within shift_duration hours of anchor belong to the period', () {
      // Anchor 08:00 May4, span = 24h → end 08:00 May5.
      // All 4 timestamps are within [08:00 May4, 08:00 May5].
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 4, 14, 0),
        dt(2026, 5, 4, 20, 0),
        dt(2026, 5, 5, 2, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        settings: settings,
      );

      expect(result.periods, hasLength(1));
      expect(result.periods.first.timestamps, hasLength(4));
    });

    test('timestamp exactly at period end (anchor + shift_duration) belongs to the current period', () {
      // anchor = 08:00 May4, periodEnd = 08:00 May5 exactly.
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 5, 8, 0), // exactly at period end
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        settings: settings,
      );

      expect(result.periods.first.timestamps, hasLength(2));
    });
  });

  // ── Gap window (shared timestamp) ────────────────────────────────────────────

  group('ShiftPeriodExtractor.extract — gap window / shared timestamp', () {
    test('next timestamp within gap window triggers shared-timestamp mechanism', () {
      // Period 1: anchor 08:00 May4. Last ts = 07:30 May5 (inside 24h span).
      // Next ts = 09:00 May5 — within 6h of 07:30 May5 → gap trigger.
      // Period 2 anchor = 07:30 May5 (shared).
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 4, 14, 0),
        dt(2026, 5, 4, 20, 0),
        dt(2026, 5, 5, 7, 30),  // last of period 1
        dt(2026, 5, 5, 9, 0),   // within 6h gap → triggers shared anchor
        dt(2026, 5, 5, 14, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        settings: settings,
      );

      expect(result.periods, hasLength(2));
      expect(result.periods[1].anchorTimestamp, dt(2026, 5, 5, 7, 30));
    });

    test('shared timestamp appears as last in closing period and first in opening period', () {
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 4, 14, 0),
        dt(2026, 5, 4, 20, 0),
        dt(2026, 5, 5, 7, 30),  // shared timestamp
        dt(2026, 5, 5, 12, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        settings: settings,
      );

      expect(result.periods, hasLength(2));
      // Closing period: last timestamp is the shared one.
      expect(result.periods[0].timestamps.last, dt(2026, 5, 5, 7, 30));
      // Opening period: anchor and first timestamp are the shared one.
      expect(result.periods[1].anchorTimestamp, dt(2026, 5, 5, 7, 30));
      expect(result.periods[1].timestamps.first, dt(2026, 5, 5, 7, 30));
    });
  });

  // ── Start-time scan (gap missed) ─────────────────────────────────────────────

  group('ShiftPeriodExtractor.extract — start-time scan after gap missed', () {
    test('when gap window is missed, scans forward for next timestamp matching fixed start time', () {
      // Period 1: anchor 08:00 May4. Last ts = 07:00 May5.
      // Next ts = 18:00 May5 — 11h after 07:00 → beyond 6h gap window.
      // 18:00 does not match 08:00 ± 30 → skipped.
      // 08:15 May6 matches → period 2 anchor.
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 4, 14, 0),
        dt(2026, 5, 4, 20, 0),
        dt(2026, 5, 5, 7, 0),   // last of period 1
        dt(2026, 5, 5, 18, 0),  // beyond gap window AND not matching 08:00 ± 30 → skipped
        dt(2026, 5, 6, 8, 15),  // matches 08:00 ± 30 → period 2 anchor
        dt(2026, 5, 6, 14, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        settings: settings,
      );

      expect(result.periods, hasLength(2));
      expect(result.periods[1].anchorTimestamp, dt(2026, 5, 6, 8, 15));
    });

    test('timestamps between periods that do not match start time are discarded', () {
      // 18:00 May5 is absorbed into neither period — it is skipped during start-time scan.
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 5, 7, 0),   // last of period 1
        dt(2026, 5, 5, 18, 0),  // skipped
        dt(2026, 5, 6, 8, 0),   // period 2 anchor
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        settings: settings,
      );

      expect(result.periods[0].timestamps, isNot(contains(dt(2026, 5, 5, 18, 0))));
      expect(result.periods[1].timestamps, isNot(contains(dt(2026, 5, 5, 18, 0))));
    });
  });

  // ── Result metadata ──────────────────────────────────────────────────────────

  group('ShiftPeriodExtractor.extract — result metadata', () {
    test('carries employee name and department into result', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 8, 0)],
        settings: settings,
      );
      expect(result.name, 'محمود');
      expect(result.department, 'الحراسة');
    });
  });
}
