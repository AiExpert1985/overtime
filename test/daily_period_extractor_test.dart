import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reporting/application/daily_period_extractor.dart';
import 'package:overtime/shared/domain/day_type.dart';
import 'package:overtime/shared/domain/employee.dart';
import 'package:overtime/shared/domain/holiday.dart';

void main() {
  final extractor = DailyPeriodExtractor();

  const employee = Employee(
    name: 'أحمد',
    employmentType: EmploymentType.daily,
    department: 'IT',
  );

  DateTime dt(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime(year, month, day, hour, minute);

  // Reference dates:
  // 2026-05-04 Monday  → regular
  // 2026-05-05 Tuesday → regular
  // 2026-05-06 Wednesday → regular
  // 2026-05-08 Friday  → weekend
  // 2026-05-09 Saturday → weekend

  group('DailyPeriodExtractor.extract', () {
    test('groups timestamps by calendar date into separate periods', () {
      final timestamps = [
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 4, 17, 30),
        dt(2026, 5, 5, 8, 0),
        dt(2026, 5, 5, 17, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        holidays: [],
      );

      expect(result.periods, hasLength(2));
      expect(result.periods[0].timestamps, hasLength(2));
      expect(result.periods[1].timestamps, hasLength(2));
    });

    test('classifies Friday as weekend', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 8, 9, 0)],
        holidays: [],
      );
      expect(result.periods.first.dayType, DayType.weekend);
    });

    test('classifies Saturday as weekend', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 9, 9, 0)],
        holidays: [],
      );
      expect(result.periods.first.dayType, DayType.weekend);
    });

    test('classifies date in holidays list as holiday', () {
      final holiday = Holiday(date: dt(2026, 5, 4), occasion: 'عطلة');
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 9, 0)],
        holidays: [holiday],
      );
      expect(result.periods.first.dayType, DayType.holiday);
    });

    test('classifies ordinary weekday not in holidays as regular', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 9, 0)],
        holidays: [],
      );
      expect(result.periods.first.dayType, DayType.regular);
    });

    test('returns periods ordered by date ascending', () {
      // Supply timestamps in reverse date order — output must still be sorted.
      final timestamps = [
        dt(2026, 5, 6, 8, 0),
        dt(2026, 5, 4, 8, 0),
        dt(2026, 5, 5, 8, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        holidays: [],
      );

      expect(result.periods[0].date, DateTime(2026, 5, 4));
      expect(result.periods[1].date, DateTime(2026, 5, 5));
      expect(result.periods[2].date, DateTime(2026, 5, 6));
    });

    test('timestamps within a period are sorted ascending', () {
      // Supply out-of-order timestamps for the same day.
      final timestamps = [
        dt(2026, 5, 4, 17, 30),
        dt(2026, 5, 4, 8, 0),
      ];

      final result = extractor.extract(
        employee: employee,
        timestamps: timestamps,
        holidays: [],
      );

      final pts = result.periods.first.timestamps;
      expect(pts.first, dt(2026, 5, 4, 8, 0));
      expect(pts.last, dt(2026, 5, 4, 17, 30));
    });

    test('excludes days with zero timestamps', () {
      // Only May 4 has timestamps — May 5 must not appear.
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 8, 0)],
        holidays: [],
      );

      expect(result.periods, hasLength(1));
      expect(result.periods.first.date, DateTime(2026, 5, 4));
    });

    test('includes day with exactly one timestamp — validity is the calculator\'s concern', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 8, 0)],
        holidays: [],
      );

      expect(result.periods, hasLength(1));
      expect(result.periods.first.timestamps, hasLength(1));
    });

    test('weekend classification takes priority over holiday for the same date', () {
      // A Friday that also appears in the holidays list must be classified weekend.
      // Calculator applies the same rules to both types so this is a classification
      // order detail, not a calculation difference — but the design is explicit: check
      // weekday first.
      final holiday = Holiday(date: dt(2026, 5, 8), occasion: 'عطلة');
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 8, 9, 0)],
        holidays: [holiday],
      );
      expect(result.periods.first.dayType, DayType.weekend);
    });

    test('carries employee name and department into result', () {
      final result = extractor.extract(
        employee: employee,
        timestamps: [dt(2026, 5, 4, 8, 0)],
        holidays: [],
      );
      expect(result.name, 'أحمد');
      expect(result.department, 'IT');
    });
  });
}
