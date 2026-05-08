import 'package:intl/intl.dart';

import '../../../shared/domain/daily_employee_result.dart';
import '../../../shared/domain/day_type.dart';
import '../../../shared/domain/raw_daily_employee_periods.dart';

class DailyCalculatorSettings {
  final String startTime;
  final int workDurationHours;
  final int maxOvertimeHours;

  const DailyCalculatorSettings({
    required this.startTime,
    required this.workDurationHours,
    required this.maxOvertimeHours,
  });
}

class DailyOvertimeCalculator {
  static const _arabicDateFormat = 'ar';

  DailyEmployeeResult calculate({
    required RawDailyEmployeePeriods rawPeriods,
    required DailyCalculatorSettings settings,
  }) {
    final startMinutes = _parseHHMM(settings.startTime);
    final endMinutes = startMinutes + settings.workDurationHours * 60;
    final maxOvertimeMinutes = settings.maxOvertimeHours * 60;

    final periods = <DailyPeriodDetail>[];
    int totalRegular = 0;
    int totalHoliday = 0;

    for (final period in rawPeriods.periods) {
      final detail = _calcPeriod(
        period: period,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        maxOvertimeMinutes: maxOvertimeMinutes,
      );
      periods.add(detail);

      if (detail.isValid) {
        if (period.dayType == DayType.regular) {
          totalRegular += detail.overtimeMinutes;
        } else {
          totalHoliday += detail.overtimeMinutes;
        }
      }
    }

    return DailyEmployeeResult(
      name: rawPeriods.name,
      department: rawPeriods.department,
      isUnmatched: false,
      totalRegularOvertimeMinutes: totalRegular,
      totalHolidayOvertimeMinutes: totalHoliday,
      periods: periods,
    );
  }

  DailyPeriodDetail _calcPeriod({
    required RawDailyPeriod period,
    required int startMinutes,
    required int endMinutes,
    required int maxOvertimeMinutes,
  }) {
    final ts = period.timestamps;
    final weekday =
        DateFormat('EEEE', _arabicDateFormat).format(period.date);

    if (ts.length < 2) {
      return DailyPeriodDetail(
        date: period.date,
        weekday: weekday,
        dayType: period.dayType,
        timestamps: ts,
        totalAttendanceDuration: ts.isEmpty
            ? 0
            : ts.last.difference(ts.first).inMinutes,
        overtimeMinutes: 0,
        isValid: false,
        notes: 'بصمة واحدة فقط',
      );
    }

    final duration = ts.last.difference(ts.first).inMinutes;

    if (period.dayType == DayType.regular) {
      final firstMinutes = ts.first.hour * 60 + ts.first.minute;
      if (firstMinutes > startMinutes) {
        return DailyPeriodDetail(
          date: period.date,
          weekday: weekday,
          dayType: period.dayType,
          timestamps: ts,
          totalAttendanceDuration: duration,
          overtimeMinutes: 0,
          isValid: false,
          notes: 'البصمة الأولى تتجاوز وقت البداية المحدد',
        );
      }

      final lastMinutes = ts.last.hour * 60 + ts.last.minute;
      final overtime = (lastMinutes - endMinutes).clamp(0, maxOvertimeMinutes);
      return DailyPeriodDetail(
        date: period.date,
        weekday: weekday,
        dayType: period.dayType,
        timestamps: ts,
        totalAttendanceDuration: duration,
        overtimeMinutes: overtime,
        isValid: true,
      );
    }

    // Holiday / weekend: no start constraint
    final overtime = duration.clamp(0, maxOvertimeMinutes);
    return DailyPeriodDetail(
      date: period.date,
      weekday: weekday,
      dayType: period.dayType,
      timestamps: ts,
      totalAttendanceDuration: duration,
      overtimeMinutes: overtime,
      isValid: true,
    );
  }

  int _parseHHMM(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
