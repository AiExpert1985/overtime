import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/data/report_repository.dart';
import '../../../shared/database/database_helper.dart';
import '../../../shared/domain/attendance_record.dart';
import '../../../shared/domain/daily_employee_result.dart';
import '../../../shared/domain/employee.dart';
import '../../../shared/domain/holiday.dart';
import '../../../shared/domain/shift_employee_result.dart';
import '../../reporting/presentation/providers/settings_providers.dart';
import 'daily_overtime_calculator.dart';
import 'daily_period_extractor.dart';
import 'shift_overtime_calculator.dart';
import 'shift_period_extractor.dart';

class EmployeeDictionaryEntry {
  final Employee employee;
  final List<DateTime> timestamps;

  const EmployeeDictionaryEntry({
    required this.employee,
    required this.timestamps,
  });
}

class DictionaryBuildResult {
  final Map<String, EmployeeDictionaryEntry> matched;
  final List<Employee> unmatched;

  const DictionaryBuildResult({
    required this.matched,
    required this.unmatched,
  });
}

class ReportGenerationService {
  final _dailyExtractor = DailyPeriodExtractor();
  final _shiftExtractor = ShiftPeriodExtractor();
  final _dailyCalculator = DailyOvertimeCalculator();
  final _shiftCalculator = ShiftOvertimeCalculator();
  final _repo = ReportRepository(DatabaseHelper.instance);

  DictionaryBuildResult buildDictionary({
    required List<Employee> employees,
    required List<AttendanceRecord> attendance,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // Build lookup map: name → employee (last row wins on duplicate names)
    final employeeMap = <String, Employee>{};
    for (final e in employees) {
      employeeMap[e.name] = e;
    }

    // Single-pass over all attendance records — filter by name and date range
    final matched = <String, EmployeeDictionaryEntry>{};

    for (final record in attendance) {
      final employee = employeeMap[record.employeeName];
      if (employee == null) continue;

      final inRange = record.fingerprints
          .where((ts) =>
              !ts.isBefore(startDate) &&
              !ts.isAfter(endDate.add(const Duration(days: 1))))
          .toList();

      if (inRange.isEmpty) continue;

      if (matched.containsKey(employee.name)) {
        // Merge fingerprints from multiple attendance files
        final existing = matched[employee.name]!;
        final merged = [...existing.timestamps, ...inRange]..sort();
        matched[employee.name] =
            EmployeeDictionaryEntry(employee: employee, timestamps: merged);
      } else {
        matched[employee.name] = EmployeeDictionaryEntry(
          employee: employee,
          timestamps: inRange,
        );
      }
    }

    // Sort each employee's timestamps ascending
    for (final entry in matched.values) {
      entry.timestamps.sort();
    }

    // Detect unmatched: employees in target list with no dictionary entry
    final unmatched =
        employees.where((e) => !matched.containsKey(e.name)).toList();

    return DictionaryBuildResult(matched: matched, unmatched: unmatched);
  }

  Future<int> runPipeline({
    required DictionaryBuildResult dictResult,
    required List<Holiday> holidays,
    required DateTime startDate,
    required DateTime endDate,
    required SettingsState settings,
  }) async {
    final dailySettings = DailyCalculatorSettings(
      startTime: settings.dailyStartTime,
      workDurationHours: settings.dailyWorkDuration,
      maxOvertimeHours: settings.dailyMaxOvertime,
    );

    final shiftExtractorSettings = ShiftExtractorSettings(
      startTimes: settings.shiftStartTimes,
      shiftDurationHours: settings.shiftDuration,
      startEndToleranceMinutes: settings.shiftStartEndTolerance,
      periodGapHours: settings.shiftPeriodGap,
    );

    final shiftCalcSettings = ShiftCalculatorSettings(
      shiftDurationHours: settings.shiftDuration,
      zoneIntervalHours: settings.shiftZoneInterval,
      startEndToleranceMinutes: settings.shiftStartEndTolerance,
      innerToleranceMinutes: settings.shiftInnerTolerance,
      baselineHours: settings.shiftBaselineHours,
      ceilingHours: settings.shiftCeilingHours,
    );

    final dailyResults = <DailyEmployeeResult>[];
    final shiftResults = <ShiftEmployeeResult>[];

    // Process matched employees
    for (final entry in dictResult.matched.values) {
      if (entry.employee.employmentType == EmploymentType.daily) {
        final raw = _dailyExtractor.extract(
          employee: entry.employee,
          timestamps: entry.timestamps,
          holidays: holidays,
        );
        dailyResults.add(_dailyCalculator.calculate(
          rawPeriods: raw,
          settings: dailySettings,
        ));
      } else {
        final raw = _shiftExtractor.extract(
          employee: entry.employee,
          timestamps: entry.timestamps,
          settings: shiftExtractorSettings,
        );
        shiftResults.add(_shiftCalculator.calculate(
          rawPeriods: raw,
          settings: shiftCalcSettings,
        ));
      }
    }

    // Add unmatched employees with zero overtime
    for (final employee in dictResult.unmatched) {
      const notes = 'لم يتم العثور على سجلات للحضور، يجب التحقق من صحة الاسم';
      if (employee.employmentType == EmploymentType.daily) {
        dailyResults.add(DailyEmployeeResult(
          name: employee.name,
          department: employee.department,
          isUnmatched: true,
          notes: notes,
          totalRegularOvertimeMinutes: 0,
          totalHolidayOvertimeMinutes: 0,
          periods: [],
        ));
      } else {
        shiftResults.add(ShiftEmployeeResult(
          name: employee.name,
          department: employee.department,
          isUnmatched: true,
          notes: notes,
          totalOvertimeHours: 0,
          periods: [],
        ));
      }
    }

    return _repo.insertReport(
      rangeStart: startDate,
      rangeEnd: endDate,
      dailyResults: dailyResults,
      shiftResults: shiftResults,
    );
  }

  Future<String?> exportUnmatchedNames(List<String> names) async {
    try {
      final excel = Excel.createExcel();
      final sheetName = 'الأسماء غير الموجودة';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      for (final name in names) {
        sheet.appendRow([TextCellValue(name)]);
      }

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file =
          File('${downloadsDir.path}/unmatched_$timestamp.xlsx');
      final bytes = excel.encode();
      if (bytes == null) return null;

      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
