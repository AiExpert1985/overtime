import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overtime/features/reporting/application/daily_overtime_calculator.dart';
import 'package:overtime/shared/domain/day_type.dart';
import 'package:overtime/shared/domain/raw_daily_employee_periods.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));

  // Default settings from config.md: start 09:00, 8h work, max 3h overtime.
  const settings = DailyCalculatorSettings(
    startTime: '09:00',
    workDurationHours: 8,     // end_time = 17:00
    maxOvertimeHours: 3,      // 180 min cap
  );

  final calculator = DailyOvertimeCalculator();

  DateTime dt(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime(year, month, day, hour, minute);

  RawDailyEmployeePeriods makeInput(List<RawDailyPeriod> periods) =>
      RawDailyEmployeePeriods(name: 'علي', department: 'HR', periods: periods);

  RawDailyPeriod regularPeriod(List<DateTime> timestamps) => RawDailyPeriod(
        date: DateTime(2026, 5, 4), // Monday
        dayType: DayType.regular,
        timestamps: timestamps,
      );

  // ── Regular day ─────────────────────────────────────────────────────────────

  group('DailyOvertimeCalculator.calculate — regular day', () {
    test('valid when first ≤ start_time and ≥2 timestamps; overtime = last − end_time', () {
      // 08:30 first (≤ 09:00) → valid. Last = 18:00. end_time = 17:00. OT = 60 min.
      final period = regularPeriod([dt(2026, 5, 4, 8, 30), dt(2026, 5, 4, 18, 0)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isTrue);
      expect(result.periods.first.overtimeMinutes, 60);
    });

    test('overtime is zero when employee leaves before end_time', () {
      // Last = 16:00 < 17:00 → no overtime.
      final period = regularPeriod([dt(2026, 5, 4, 8, 0), dt(2026, 5, 4, 16, 0)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isTrue);
      expect(result.periods.first.overtimeMinutes, 0);
    });

    test('first timestamp exactly at start_time is valid', () {
      // Boundary: first == start_time → "not later than" → valid.
      final period = regularPeriod([dt(2026, 5, 4, 9, 0), dt(2026, 5, 4, 17, 30)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isTrue);
    });

    test('overtime is capped at configured daily maximum', () {
      // Last = 22:00 → would be 5h OT; capped at 3h = 180 min.
      final period = regularPeriod([dt(2026, 5, 4, 8, 0), dt(2026, 5, 4, 22, 0)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.overtimeMinutes, 180);
    });

    test('invalid when first timestamp is after start_time', () {
      // 09:30 > 09:00 → invalid with correct Arabic note.
      final period = regularPeriod([dt(2026, 5, 4, 9, 30), dt(2026, 5, 4, 17, 30)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isFalse);
      expect(result.periods.first.overtimeMinutes, 0);
      expect(result.periods.first.notes, 'البصمة الأولى تتجاوز وقت البداية المحدد');
    });

    test('invalid when only one timestamp', () {
      final period = regularPeriod([dt(2026, 5, 4, 8, 0)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isFalse);
      expect(result.periods.first.notes, 'بصمة واحدة فقط');
    });

    test('invalid period contributes zero to regular overtime total', () {
      final period = regularPeriod([dt(2026, 5, 4, 8, 0)]); // single timestamp → invalid
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.totalRegularOvertimeMinutes, 0);
    });
  });

  // ── Holiday / weekend day ────────────────────────────────────────────────────

  group('DailyOvertimeCalculator.calculate — holiday / weekend day', () {
    test('holiday day: valid with ≥2 timestamps regardless of first timestamp time', () {
      // First at 10:00 — after daily start_time — still valid because start constraint is lifted.
      final period = RawDailyPeriod(
        date: DateTime(2026, 5, 4),
        dayType: DayType.holiday,
        timestamps: [dt(2026, 5, 4, 10, 0), dt(2026, 5, 4, 18, 0)],
      );

      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isTrue);
    });

    test('holiday day: overtime = full span from first to last timestamp', () {
      // 10:00 to 18:00 = 8h = 480 min, capped at 3h = 180 min.
      final period = RawDailyPeriod(
        date: DateTime(2026, 5, 4),
        dayType: DayType.holiday,
        timestamps: [dt(2026, 5, 4, 10, 0), dt(2026, 5, 4, 18, 0)],
      );

      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.overtimeMinutes, 180); // capped at 3h
    });

    test('holiday day: short span is not capped', () {
      // 10:00 to 12:00 = 2h = 120 min < 180 min cap.
      final period = RawDailyPeriod(
        date: DateTime(2026, 5, 4),
        dayType: DayType.holiday,
        timestamps: [dt(2026, 5, 4, 10, 0), dt(2026, 5, 4, 12, 0)],
      );

      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.overtimeMinutes, 120);
    });

    test('weekend day: valid with ≥2 timestamps even when first is after daily start_time', () {
      final period = RawDailyPeriod(
        date: DateTime(2026, 5, 8), // Friday
        dayType: DayType.weekend,
        timestamps: [dt(2026, 5, 8, 11, 0), dt(2026, 5, 8, 13, 0)],
      );

      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isTrue);
    });

    test('holiday day: invalid when only one timestamp', () {
      final period = RawDailyPeriod(
        date: DateTime(2026, 5, 4),
        dayType: DayType.holiday,
        timestamps: [dt(2026, 5, 4, 9, 0)],
      );

      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.isValid, isFalse);
      expect(result.periods.first.notes, 'بصمة واحدة فقط');
    });
  });

  // ── Monthly totals ───────────────────────────────────────────────────────────

  group('DailyOvertimeCalculator.calculate — monthly totals', () {
    test('regular and holiday overtime are accumulated into separate monthly totals', () {
      final periods = [
        // Regular: OT = 18:00 − 17:00 = 60 min
        RawDailyPeriod(
          date: DateTime(2026, 5, 4),
          dayType: DayType.regular,
          timestamps: [dt(2026, 5, 4, 8, 0), dt(2026, 5, 4, 18, 0)],
        ),
        // Holiday: OT = 12:00 − 10:00 = 120 min
        RawDailyPeriod(
          date: DateTime(2026, 5, 5),
          dayType: DayType.holiday,
          timestamps: [dt(2026, 5, 5, 10, 0), dt(2026, 5, 5, 12, 0)],
        ),
      ];

      final result = calculator.calculate(rawPeriods: makeInput(periods), settings: settings);

      expect(result.totalRegularOvertimeMinutes, 60);
      expect(result.totalHolidayOvertimeMinutes, 120);
    });

    test('invalid periods do not contribute to either monthly total', () {
      final periods = [
        // Only one timestamp → invalid
        regularPeriod([dt(2026, 5, 4, 8, 0)]),
        // First after start_time → invalid
        regularPeriod([dt(2026, 5, 5, 9, 30), dt(2026, 5, 5, 18, 0)]),
      ];

      final result = calculator.calculate(rawPeriods: makeInput(periods), settings: settings);

      expect(result.totalRegularOvertimeMinutes, 0);
      expect(result.totalHolidayOvertimeMinutes, 0);
    });

    test('weekend overtime accumulates into the holiday total, not the regular total', () {
      final period = RawDailyPeriod(
        date: DateTime(2026, 5, 8), // Friday
        dayType: DayType.weekend,
        timestamps: [dt(2026, 5, 8, 9, 0), dt(2026, 5, 8, 11, 0)],
      );

      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.totalRegularOvertimeMinutes, 0);
      expect(result.totalHolidayOvertimeMinutes, 120);
    });
  });

  // ── totalAttendanceDuration ──────────────────────────────────────────────────

  group('DailyOvertimeCalculator.calculate — totalAttendanceDuration', () {
    test('is real first-to-last span in minutes, independent of overtime', () {
      // 08:00 to 16:00 = 8h = 480 min span, but no overtime (leaves before 17:00).
      final period = regularPeriod([dt(2026, 5, 4, 8, 0), dt(2026, 5, 4, 16, 0)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: settings);

      expect(result.periods.first.totalAttendanceDuration, 480);
      expect(result.periods.first.overtimeMinutes, 0);
    });
  });

  // ── end_time derivation ──────────────────────────────────────────────────────

  group('DailyOvertimeCalculator.calculate — end_time derivation', () {
    test('end_time shifts with work_duration — changing duration changes the overtime boundary', () {
      // With 6h duration: end_time = 09:00 + 6h = 15:00. Employee leaves 16:00 → 60 min OT.
      const shortDay = DailyCalculatorSettings(
        startTime: '09:00',
        workDurationHours: 6,
        maxOvertimeHours: 3,
      );
      final period = regularPeriod([dt(2026, 5, 4, 8, 0), dt(2026, 5, 4, 16, 0)]);
      final result = calculator.calculate(rawPeriods: makeInput([period]), settings: shortDay);

      expect(result.periods.first.overtimeMinutes, 60);
    });
  });

  // ── result metadata ──────────────────────────────────────────────────────────

  group('DailyOvertimeCalculator.calculate — result metadata', () {
    test('isUnmatched is always false — unmatched path is handled by the orchestrator', () {
      final result = calculator.calculate(rawPeriods: makeInput([]), settings: settings);
      expect(result.isUnmatched, isFalse);
    });
  });
}
