import '../../../shared/domain/day_type.dart';
import '../../../shared/domain/employee.dart';
import '../../../shared/domain/holiday.dart';
import '../../../shared/domain/raw_daily_employee_periods.dart';

class DailyPeriodExtractor {
  RawDailyEmployeePeriods extract({
    required Employee employee,
    required List<DateTime> timestamps,
    required List<Holiday> holidays,
  }) {
    final holidayDates =
        holidays.map((h) => _dateOnly(h.date)).toSet();

    final Map<DateTime, List<DateTime>> byDate = {};
    for (final ts in timestamps) {
      final date = _dateOnly(ts);
      byDate.putIfAbsent(date, () => []).add(ts);
    }

    final periods = byDate.entries.map((entry) {
      final date = entry.key;
      final dayTimestamps = List<DateTime>.from(entry.value)..sort();
      return RawDailyPeriod(
        date: date,
        dayType: _classify(date, holidayDates),
        timestamps: dayTimestamps,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return RawDailyEmployeePeriods(
      name: employee.name,
      department: employee.department,
      periods: periods,
    );
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DayType _classify(DateTime date, Set<DateTime> holidayDates) {
    if (date.weekday == DateTime.friday ||
        date.weekday == DateTime.saturday) {
      return DayType.weekend;
    }
    if (holidayDates.contains(date)) return DayType.holiday;
    return DayType.regular;
  }
}
