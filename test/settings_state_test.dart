import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reporting/presentation/providers/settings_providers.dart';

void main() {
  group('SettingsState.dailyEndTime', () {
    SettingsState make({required String start, required int duration}) =>
        SettingsState(
          dailyStartTime: start,
          dailyWorkDuration: duration,
          dailyMaxOvertime: 3,
          shiftStartTimes: ['08:00'],
          shiftDuration: 24,
          shiftZoneInterval: 6,
          shiftStartEndTolerance: 30,
          shiftInnerTolerance: 60,
          shiftPeriodGap: 6,
          shiftBaselineHours: 154,
          shiftCeilingHours: 192,
          roundingMode: 'quarter',
          maxReportDateRange: 31,
        );

    test('derives end time correctly from default settings (09:00 + 8h = 17:00)', () {
      expect(make(start: '09:00', duration: 8).dailyEndTime, '17:00');
    });

    test('derives end time with zero-padded minutes', () {
      expect(make(start: '09:05', duration: 8).dailyEndTime, '17:05');
    });

    test('wraps past midnight', () {
      expect(make(start: '22:00', duration: 8).dailyEndTime, '06:00');
    });

    test('returns empty string for malformed start time', () {
      expect(make(start: 'invalid', duration: 8).dailyEndTime, '');
    });
  });

  group('SettingsState.shiftZoneCount', () {
    SettingsState make({required int duration, required int interval}) =>
        SettingsState(
          dailyStartTime: '09:00',
          dailyWorkDuration: 8,
          dailyMaxOvertime: 3,
          shiftStartTimes: ['08:00'],
          shiftDuration: duration,
          shiftZoneInterval: interval,
          shiftStartEndTolerance: 30,
          shiftInnerTolerance: 60,
          shiftPeriodGap: 6,
          shiftBaselineHours: 154,
          shiftCeilingHours: 192,
          roundingMode: 'quarter',
          maxReportDateRange: 31,
        );

    test('derives zone count from defaults (24h / 6h = 4)', () {
      expect(make(duration: 24, interval: 6).shiftZoneCount, 4);
    });

    test('returns 0 when interval is 0 (guard against divide-by-zero)', () {
      expect(make(duration: 24, interval: 0).shiftZoneCount, 0);
    });

    test('truncates remainder (25 / 6 = 4)', () {
      expect(make(duration: 25, interval: 6).shiftZoneCount, 4);
    });
  });
}
