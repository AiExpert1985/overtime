import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reporting/application/shift_overtime_calculator.dart';
import 'package:overtime/shared/domain/raw_shift_employee_periods.dart';

void main() {
  // Default settings from config.md.
  // 4 zones: anchor, anchor+6h, anchor+12h, anchor+18h.
  // Zone 0 (first) and zone 3 (last) use ±30 min tolerance.
  // Zones 1 and 2 (inner) use ±60 min tolerance.
  const settings = ShiftCalculatorSettings(
    shiftDurationHours: 24,
    zoneIntervalHours: 6,
    startEndToleranceMinutes: 30,
    innerToleranceMinutes: 60,
    baselineHours: 154,
    ceilingHours: 192,
  );

  final calculator = ShiftOvertimeCalculator();

  DateTime dt(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime(year, month, day, hour, minute);

  RawShiftPeriod makePeriod(DateTime anchor, List<DateTime> timestamps) =>
      RawShiftPeriod(anchorTimestamp: anchor, timestamps: timestamps);

  RawShiftEmployeePeriods makeInput(List<RawShiftPeriod> periods) =>
      RawShiftEmployeePeriods(name: 'فاطمة', department: 'الأمن', periods: periods);

  // Reference anchor: 2026-05-04 08:00.
  // Zone centers: 08:00, 14:00, 20:00, 02:00 May5.
  // Zone 0 window: [07:30, 08:30]. Zone 1: [13:00, 15:00]. Zone 2: [19:00, 21:00]. Zone 3: [01:30, 02:30].
  final anchor = dt(2026, 5, 4, 8, 0);

  List<DateTime> allZonesSatisfied() => [
        dt(2026, 5, 4, 8, 0),   // zone 0 ✓
        dt(2026, 5, 4, 14, 0),  // zone 1 ✓
        dt(2026, 5, 4, 20, 0),  // zone 2 ✓
        dt(2026, 5, 5, 2, 0),   // zone 3 ✓
      ];

  // Builds N valid periods, each 24h apart from the same anchor pattern.
  List<RawShiftPeriod> nValidPeriods(int n) => List.generate(n, (i) {
        final a = anchor.add(Duration(hours: 24 * i));
        return makePeriod(
          a,
          allZonesSatisfied().map((ts) => ts.add(Duration(hours: 24 * i))).toList(),
        );
      });

  // ── Period validity ──────────────────────────────────────────────────────────

  group('ShiftOvertimeCalculator.calculate — period validity', () {
    test('period valid when all zones have at least one timestamp within tolerance', () {
      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, allZonesSatisfied())]),
        settings: settings,
      );

      expect(result.periods.first.isValid, isTrue);
      expect(result.periods.first.hoursCounted, 24);
      expect(result.periods.first.notes, isNull);
    });

    test('period invalid when any zone has no timestamp within tolerance', () {
      // Zone 2 (20:00 ± 60 min = [19:00, 21:00]) has no timestamp.
      final timestamps = [
        dt(2026, 5, 4, 8, 0),   // zone 0 ✓
        dt(2026, 5, 4, 14, 0),  // zone 1 ✓
        // no timestamp between 19:00–21:00
        dt(2026, 5, 5, 2, 0),   // zone 3 ✓
      ];

      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, timestamps)]),
        settings: settings,
      );

      expect(result.periods.first.isValid, isFalse);
      expect(result.periods.first.hoursCounted, 0);
    });

    test('invalid period note is the Arabic zone-missing message', () {
      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, [dt(2026, 5, 4, 8, 0)])]),
        settings: settings,
      );
      expect(result.periods.first.notes, 'يوجد فترة زمنية بدون بصمة تحقق');
    });

    test('valid period counts 24 hours regardless of actual attendance span', () {
      // Span is only ~18h but all zones satisfied → still counts as 24.
      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, allZonesSatisfied())]),
        settings: settings,
      );
      expect(result.periods.first.hoursCounted, 24);
    });

    test('invalid period counts 0 hours', () {
      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, [dt(2026, 5, 4, 8, 0)])]),
        settings: settings,
      );
      expect(result.periods.first.hoursCounted, 0);
    });
  });

  // ── Zone tolerance boundaries ────────────────────────────────────────────────

  group('ShiftOvertimeCalculator.calculate — zone tolerance', () {
    test('inner zone uses wider tolerance (±60 min) — timestamp at boundary satisfies it', () {
      // 13:05 is within zone 1 window [13:00, 15:00] (±60 from 14:00) → zone satisfied.
      final timestamps = [
        dt(2026, 5, 4, 8, 0),   // zone 0 ✓
        dt(2026, 5, 4, 13, 5),  // zone 1 ✓ — just inside ±60 window
        dt(2026, 5, 4, 20, 0),  // zone 2 ✓
        dt(2026, 5, 5, 2, 0),   // zone 3 ✓
      ];

      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, timestamps)]),
        settings: settings,
      );

      expect(result.periods.first.isValid, isTrue);
    });

    test('inner zone timestamp outside ±60 min window causes period to be invalid', () {
      // 12:45 is outside zone 1 window [13:00, 15:00] (±60 from 14:00) → zone not satisfied.
      final timestamps = [
        dt(2026, 5, 4, 8, 0),   // zone 0 ✓
        dt(2026, 5, 4, 12, 45), // zone 1 MISS — 12:45 < 13:00
        dt(2026, 5, 4, 20, 0),  // zone 2 ✓
        dt(2026, 5, 5, 2, 0),   // zone 3 ✓
      ];

      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, timestamps)]),
        settings: settings,
      );

      expect(result.periods.first.isValid, isFalse);
    });

    test('boundary zone uses narrower tolerance (±30 min) — timestamp outside it fails', () {
      // 07:20 is outside zone 0 window [07:30, 08:30] (±30 from 08:00).
      final timestamps = [
        dt(2026, 5, 4, 7, 20),  // zone 0 MISS — 07:20 < 07:30
        dt(2026, 5, 4, 14, 0),  // zone 1 ✓
        dt(2026, 5, 4, 20, 0),  // zone 2 ✓
        dt(2026, 5, 5, 2, 0),   // zone 3 ✓
      ];

      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, timestamps)]),
        settings: settings,
      );

      expect(result.periods.first.isValid, isFalse);
    });
  });

  // ── Monthly calculation ──────────────────────────────────────────────────────

  group('ShiftOvertimeCalculator.calculate — monthly calculation', () {
    test('design doc example: 10 valid periods → 240h capped to 192h − 154h baseline = 38h', () {
      final result = calculator.calculate(
        rawPeriods: makeInput(nValidPeriods(10)),
        settings: settings,
      );
      expect(result.totalOvertimeHours, 38);
    });

    test('all invalid periods → overtime is 0', () {
      final invalidPeriods = List.generate(
        10,
        (i) => makePeriod(anchor.add(Duration(hours: 24 * i)), [anchor.add(Duration(hours: 24 * i))]),
      );

      final result = calculator.calculate(
        rawPeriods: makeInput(invalidPeriods),
        settings: settings,
      );

      expect(result.totalOvertimeHours, 0);
    });

    test('worked hours below baseline → overtime is 0, not negative', () {
      // 5 valid periods = 120h < 154h baseline → overtime must be 0.
      final result = calculator.calculate(
        rawPeriods: makeInput(nValidPeriods(5)),
        settings: settings,
      );
      expect(result.totalOvertimeHours, 0);
    });

    test('ceiling is applied to worked hours before subtracting baseline', () {
      // Custom: ceiling=48h, baseline=24h. 10 valid periods = 240h → capped 48h → minus 24h = 24h.
      const customSettings = ShiftCalculatorSettings(
        shiftDurationHours: 24,
        zoneIntervalHours: 6,
        startEndToleranceMinutes: 30,
        innerToleranceMinutes: 60,
        baselineHours: 24,
        ceilingHours: 48,
      );

      final result = calculator.calculate(
        rawPeriods: makeInput(nValidPeriods(10)),
        settings: customSettings,
      );

      expect(result.totalOvertimeHours, 24);
    });

    test('exactly at baseline → overtime is 0', () {
      // 154h / 24h per period ≈ 6.4 → need ceiling trick. Use custom baseline=120, ceiling=200.
      // 5 valid periods = 120h → exactly at baseline → overtime = 0.
      const customSettings = ShiftCalculatorSettings(
        shiftDurationHours: 24,
        zoneIntervalHours: 6,
        startEndToleranceMinutes: 30,
        innerToleranceMinutes: 60,
        baselineHours: 120,
        ceilingHours: 200,
      );

      final result = calculator.calculate(
        rawPeriods: makeInput(nValidPeriods(5)),
        settings: customSettings,
      );

      expect(result.totalOvertimeHours, 0);
    });
  });

  // ── totalAttendanceDuration ──────────────────────────────────────────────────

  group('ShiftOvertimeCalculator.calculate — totalAttendanceDuration', () {
    test('is real first-to-last span in minutes, not 24 fixed hours', () {
      // Span: 08:00 May4 to 02:00 May5 = 18h = 1080 min, all zones satisfied → counts as 24h.
      final result = calculator.calculate(
        rawPeriods: makeInput([makePeriod(anchor, allZonesSatisfied())]),
        settings: settings,
      );

      expect(result.periods.first.totalAttendanceDuration, 1080);
      expect(result.periods.first.hoursCounted, 24);
    });
  });

  // ── result metadata ──────────────────────────────────────────────────────────

  group('ShiftOvertimeCalculator.calculate — result metadata', () {
    test('isUnmatched is always false — unmatched path is handled by the orchestrator', () {
      final result = calculator.calculate(rawPeriods: makeInput([]), settings: settings);
      expect(result.isUnmatched, isFalse);
    });
  });
}
