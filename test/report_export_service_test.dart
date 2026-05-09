import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overtime/features/reporting/application/report_export_service.dart';
import 'package:overtime/shared/domain/daily_employee_result.dart';
import 'package:overtime/shared/domain/day_type.dart';
import 'package:overtime/shared/domain/report_data.dart';
import 'package:overtime/shared/domain/shift_employee_result.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String _downloadsPath;
  _FakePathProvider(this._downloadsPath);

  @override
  Future<String?> getDownloadsPath() async => _downloadsPath;
}

void main() {
  late Directory tmpDir;
  late ReportExportService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ar');
    tmpDir = await Directory.systemTemp.createTemp('export_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
    service = ReportExportService();
  });

  tearDownAll(() => tmpDir.deleteSync(recursive: true));

  // ── Fixtures ─────────────────────────────────────────────────────────────────

  final rangeStart = DateTime(2026, 5, 1);
  final rangeEnd = DateTime(2026, 5, 31);

  ReportListItem makeSummary({int unmatchedCount = 0}) => ReportListItem(
        id: 1,
        generationDatetime: DateTime(2026, 5, 9),
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        totalEmployees: 5,
        totalShiftOvertimeHours: 24,
        totalDailyOvertimeMinutes: 120,
        totalHolidayOvertimeMinutes: 60,
        unmatchedEmployeeCount: unmatchedCount,
      );

  DailyEmployeeResult dailyMatched(String name,
          {int regular = 120, int holiday = 60}) =>
      DailyEmployeeResult(
        name: name,
        department: 'IT',
        isUnmatched: false,
        totalRegularOvertimeMinutes: regular,
        totalHolidayOvertimeMinutes: holiday,
        periods: [
          DailyPeriodDetail(
            date: DateTime(2026, 5, 4),
            weekday: 'الاثنين',
            dayType: DayType.regular,
            timestamps: [
              DateTime(2026, 5, 4, 8, 0),
              DateTime(2026, 5, 4, 18, 0),
            ],
            totalAttendanceDuration: 600,
            overtimeMinutes: 60,
            isValid: true,
          ),
        ],
      );

  DailyEmployeeResult dailyUnmatched(String name) => DailyEmployeeResult(
        name: name,
        department: 'IT',
        isUnmatched: true,
        notes: 'لم يتم العثور على سجلات للحضور، يجب التحقق من صحة الاسم',
        totalRegularOvertimeMinutes: 0,
        totalHolidayOvertimeMinutes: 0,
        periods: [],
      );

  ShiftEmployeeResult shiftMatched(String name, {int overtimeHours = 24}) =>
      ShiftEmployeeResult(
        name: name,
        department: 'HR',
        isUnmatched: false,
        totalOvertimeHours: overtimeHours,
        periods: [
          ShiftPeriodDetail(
            startDate: DateTime(2026, 5, 1),
            endDate: DateTime(2026, 5, 2),
            anchorTimestamp: DateTime(2026, 5, 1, 8, 0),
            timestamps: [
              DateTime(2026, 5, 1, 8, 0),
              DateTime(2026, 5, 2, 7, 59),
            ],
            totalAttendanceDuration: 1439,
            zoneResults: [
              ZoneResult(
                centerTime: DateTime(2026, 5, 1, 8, 0),
                timestamps: [DateTime(2026, 5, 1, 8, 0)],
                isSatisfied: true,
              ),
            ],
            hoursCounted: 24,
            isValid: true,
          ),
        ],
      );

  ShiftEmployeeResult shiftUnmatched(String name) => ShiftEmployeeResult(
        name: name,
        department: 'HR',
        isUnmatched: true,
        notes: 'لم يتم العثور على سجلات للحضور، يجب التحقق من صحة الاسم',
        totalOvertimeHours: 0,
        periods: [],
      );

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<Excel> runExport(
    ReportData report, {
    String roundingMode = 'none',
    int baseline = 160,
    int ceiling = 240,
  }) async {
    final path = await service.exportReport(
      report: report,
      roundingMode: roundingMode,
      baselineHours: baseline,
      ceilingHours: ceiling,
    );
    final bytes = await File(path).readAsBytes();
    return Excel.decodeBytes(bytes);
  }

  List<String> allTextIn(Sheet sheet) => sheet.rows
      .expand((row) => row)
      .where((c) => c?.value is TextCellValue)
      .map((c) => (c!.value as TextCellValue).value.toString())
      .toList();

  int rowIndexOf(Sheet sheet, String name) => sheet.rows.indexWhere((row) =>
      row.isNotEmpty &&
      row[0]?.value is TextCellValue &&
      (row[0]!.value as TextCellValue).value.toString() == name);

  // ── Sheet structure ───────────────────────────────────────────────────────────

  group('exportReport — sheet structure', () {
    test('creates exactly two sheets with correct Arabic names', () async {
      final report =
          ReportData(summary: makeSummary(), dailyResults: [], shiftResults: []);
      final excel = await runExport(report);

      expect(excel.sheets.keys,
          containsAll(['ملخص التقرير', 'تفاصيل الموظفين']));
      expect(excel.sheets.length, 2);
    });

    test('summary sheet is the default sheet', () async {
      final report =
          ReportData(summary: makeSummary(), dailyResults: [], shiftResults: []);
      final excel = await runExport(report);

      expect(excel.getDefaultSheet(), 'ملخص التقرير');
    });
  });

  // ── File naming ───────────────────────────────────────────────────────────────

  group('exportReport — file naming', () {
    test('file name encodes both date endpoints in yyyyMMdd format', () async {
      final report =
          ReportData(summary: makeSummary(), dailyResults: [], shiftResults: []);
      final path = await service.exportReport(
        report: report,
        roundingMode: 'none',
        baselineHours: 160,
        ceilingHours: 240,
      );

      expect(path, contains('report_20260501_20260531.xlsx'));
    });

    test('file is written inside Downloads directory', () async {
      final report =
          ReportData(summary: makeSummary(), dailyResults: [], shiftResults: []);
      final path = await service.exportReport(
        report: report,
        roundingMode: 'none',
        baselineHours: 160,
        ceilingHours: 240,
      );

      expect(path, startsWith(tmpDir.path));
      expect(File(path).existsSync(), isTrue);
    });
  });

  // ── Sheet 1: summary header ───────────────────────────────────────────────────

  group('exportReport — Sheet 1: summary header', () {
    test('header includes formatted date range', () async {
      final report =
          ReportData(summary: makeSummary(), dailyResults: [], shiftResults: []);
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(
        text.any((t) => t.contains('2026/05/01') && t.contains('2026/05/31')),
        isTrue,
      );
    });

    test('unmatched count row appears when count is non-zero', () async {
      final report = ReportData(
          summary: makeSummary(unmatchedCount: 3),
          dailyResults: [],
          shiftResults: []);
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('غير موجودين'));
    });

    // Intentional deviation from design: design lists unmatched count as an
    // unconditional header item; code omits the row when count == 0 to avoid
    // showing noise. Confirmed intentional by user.
    test('unmatched count row is omitted when count is zero', () async {
      final report = ReportData(
          summary: makeSummary(unmatchedCount: 0),
          dailyResults: [],
          shiftResults: []);
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, isNot(contains('غير موجودين')));
    });
  });

  // ── Sheet 1: unmatched in summary ─────────────────────────────────────────────

  group('exportReport — Sheet 1: unmatched employees appear in summary', () {
    test('unmatched daily employee row is included in Sheet 1', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 1),
        dailyResults: [dailyUnmatched('غير موجود')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('غير موجود'));
    });

    test('unmatched daily employee row carries notes text', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 1),
        dailyResults: [dailyUnmatched('غير موجود')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(
        text,
        contains(
            'لم يتم العثور على سجلات للحضور، يجب التحقق من صحة الاسم'),
      );
    });

    test('unmatched shift employee row is included in Sheet 1', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 1),
        dailyResults: [],
        shiftResults: [shiftUnmatched('غير موجود مناوب')],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('غير موجود مناوب'));
    });
  });

  // ── Sheet 2: unmatched excluded ───────────────────────────────────────────────

  group('exportReport — Sheet 2: unmatched employees excluded', () {
    test('unmatched daily employee does not appear in Sheet 2', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 1),
        dailyResults: [dailyUnmatched('غير موجود')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, isNot(contains('غير موجود')));
    });

    test('unmatched shift employee does not appear in Sheet 2', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 1),
        dailyResults: [],
        shiftResults: [shiftUnmatched('غير موجود مناوب')],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, isNot(contains('غير موجود مناوب')));
    });

    test('matched daily employee appears in Sheet 2', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف موجود')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, contains('موظف موجود'));
    });

    test('matched shift employee appears in Sheet 2', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [],
        shiftResults: [shiftMatched('مناوب موجود')],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, contains('مناوب موجود'));
    });

    test('Sheet 2 is empty when all employees are unmatched', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 2),
        dailyResults: [dailyUnmatched('أ'), dailyUnmatched('ب')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final sheet = excel.sheets['تفاصيل الموظفين']!;
      final nonEmpty = sheet.rows
          .where((row) => row.any((c) => c?.value != null))
          .toList();

      expect(nonEmpty, isEmpty);
    });
  });

  // ── Sheet 1: alphabetical sorting ─────────────────────────────────────────────

  group('exportReport — Sheet 1: alphabetical sorting', () {
    test('matched daily employees appear before unmatched, each group sorted alphabetically', () async {
      final report = ReportData(
        summary: makeSummary(unmatchedCount: 1),
        dailyResults: [
          dailyUnmatched('ياسر'),   // unmatched — must appear after all matched
          dailyMatched('محمد'),
          dailyMatched('أحمد'),
        ],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final sheet = excel.sheets['ملخص التقرير']!;

      final iAhmed = rowIndexOf(sheet, 'أحمد');
      final iMohamed = rowIndexOf(sheet, 'محمد');
      final iYaser = rowIndexOf(sheet, 'ياسر');

      expect(iAhmed, greaterThan(0));
      expect(iAhmed, lessThan(iMohamed));
      expect(iMohamed, lessThan(iYaser));
    });

    test('matched shift employees are sorted alphabetically', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [],
        shiftResults: [shiftMatched('يوسف'), shiftMatched('بدر')],
      );
      final excel = await runExport(report);
      final sheet = excel.sheets['ملخص التقرير']!;

      expect(rowIndexOf(sheet, 'بدر'), lessThan(rowIndexOf(sheet, 'يوسف')));
    });
  });

  // ── Sheet 2: ordering ─────────────────────────────────────────────────────────

  group('exportReport — Sheet 2: ordering', () {
    test('daily employee sections appear before shift sections', () async {
      // 'يوسف' (daily) vs 'أحمد' (shift) — daily must come first despite
      // 'أحمد' sorting earlier alphabetically.
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('يوسف')],
        shiftResults: [shiftMatched('أحمد')],
      );
      final excel = await runExport(report);
      final sheet = excel.sheets['تفاصيل الموظفين']!;

      expect(
        rowIndexOf(sheet, 'يوسف'),
        lessThan(rowIndexOf(sheet, 'أحمد')),
      );
    });

    test('daily employees in Sheet 2 are sorted alphabetically', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('يوسف'), dailyMatched('أحمد')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final sheet = excel.sheets['تفاصيل الموظفين']!;

      expect(
        rowIndexOf(sheet, 'أحمد'),
        lessThan(rowIndexOf(sheet, 'يوسف')),
      );
    });
  });

  // ── Sheet 2: blank rows between sections ──────────────────────────────────────

  group('exportReport — Sheet 2: blank row between sections', () {
    test('blank row separates two consecutive employee sections', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('أحمد'), dailyMatched('محمد')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final sheet = excel.sheets['تفاصيل الموظفين']!;

      final iMohamed = rowIndexOf(sheet, 'محمد');
      expect(iMohamed, greaterThan(0));

      final rowBefore = sheet.rows[iMohamed - 1];
      final isBlank = rowBefore.every((c) =>
          c == null ||
          c.value == null ||
          c.value!.toString().isEmpty);
      expect(isBlank, isTrue,
          reason: 'row immediately before second section name must be blank');
    });
  });

  // ── Sheet 1: grand total = regular + holiday ──────────────────────────────────

  group('exportReport — Sheet 1: daily grand total', () {
    test('grand total column = regular + holiday minutes formatted with rounding', () async {
      // regular = 60, holiday = 60 → total = 120 → '2 س' (mode none, exact hours)
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف', regular: 60, holiday: 60)],
        shiftResults: [],
      );
      final excel = await runExport(report, roundingMode: 'none');
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      // The row has [name, dept, regular='1 س', holiday='1 س', total='2 س'].
      // '2 س' must appear and must not be '2 س 0 د'.
      expect(text, contains('2 س'));
      expect(text, isNot(contains('2 س 0 د')));
    });
  });

  // ── Rounding — display-only ───────────────────────────────────────────────────

  group('exportReport — rounding is display-only; raw minutes are not modified', () {
    test('mode none: 75 minutes displayed as 1 س 15 د', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف', regular: 75, holiday: 0)],
        shiftResults: [],
      );
      final excel = await runExport(report, roundingMode: 'none');
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('1 س 15 د'));
    });

    test('mode quarter: 68 minutes rounds to nearest 15 → 75 min → 1 س 15 د', () async {
      // 68 / 15 = 4.53 → round → 5 → 75 min
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف', regular: 68, holiday: 0)],
        shiftResults: [],
      );
      final excel = await runExport(report, roundingMode: 'quarter');
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('1 س 15 د'));
    });

    test('mode half: 76 minutes rounds to nearest 30 → 90 min → 1 س 30 د', () async {
      // 76 / 30 = 2.53 → round → 3 → 90 min
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف', regular: 76, holiday: 0)],
        shiftResults: [],
      );
      final excel = await runExport(report, roundingMode: 'half');
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('1 س 30 د'));
    });

    test('mode hour: 91 minutes rounds to nearest 60 → 120 min → 2 س', () async {
      // 91 / 60 = 1.516 → round → 2 → 120 min
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف', regular: 91, holiday: 0)],
        shiftResults: [],
      );
      final excel = await runExport(report, roundingMode: 'hour');
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('2 س'));
    });

    test('exact hours omit the minutes component (60 min → 1 س, not 1 س 0 د)', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف', regular: 60, holiday: 0)],
        shiftResults: [],
      );
      final excel = await runExport(report, roundingMode: 'none');
      final text = allTextIn(excel.sheets['ملخص التقرير']!);

      expect(text, contains('1 س'));
      expect(text, isNot(contains('1 س 0 د')));
    });
  });

  // ── Sheet 2: period content ───────────────────────────────────────────────────

  group('exportReport — Sheet 2: period detail content', () {
    test('daily period timestamps shown as time-only — no date component', () async {
      // Timestamp is 2026-05-04 08:00 → should appear as '8:00', not with date prefix.
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, contains('8:00'));
      expect(
        text.any((s) => s.contains('2026') && s.contains('8:00')),
        isFalse,
        reason: 'date component must not appear inside timestamp cells',
      );
    });

    test('daily period day type label is Arabic', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('موظف')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, contains('عادي'));
    });

    test('invalid daily period shows notes and no overtime value', () async {
      final invalidPeriod = DailyPeriodDetail(
        date: DateTime(2026, 5, 5),
        weekday: 'الثلاثاء',
        dayType: DayType.regular,
        timestamps: [DateTime(2026, 5, 5, 9, 30)], // single timestamp → invalid
        totalAttendanceDuration: 0,
        overtimeMinutes: 0,
        isValid: false,
        notes: 'بصمة واحدة فقط',
      );
      final result = DailyEmployeeResult(
        name: 'موظف',
        department: 'IT',
        isUnmatched: false,
        totalRegularOvertimeMinutes: 0,
        totalHolidayOvertimeMinutes: 0,
        periods: [invalidPeriod],
      );
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [result],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text, contains('بصمة واحدة فقط'));
      // Invalid periods show '—' for overtime, not a formatted minutes value.
      expect(text, contains('—'));
    });

    test('shift period zone results appear in Sheet 2', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [],
        shiftResults: [shiftMatched('مناوب')],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      // Zone label prefix from the service: 'نقطة 1: ...'
      expect(text.any((s) => s.contains('نقطة 1:')), isTrue);
    });

    test('shift employee header shows employment type as مناوب', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [],
        shiftResults: [shiftMatched('مناوب')],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text.any((s) => s.contains('مناوب') && s.contains('نوع التوظيف')),
          isTrue);
    });

    test('daily employee header shows employment type as صباحي', () async {
      final report = ReportData(
        summary: makeSummary(),
        dailyResults: [dailyMatched('يومي')],
        shiftResults: [],
      );
      final excel = await runExport(report);
      final text = allTextIn(excel.sheets['تفاصيل الموظفين']!);

      expect(text.any((s) => s.contains('صباحي') && s.contains('نوع التوظيف')),
          isTrue);
    });
  });
}
