import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../domain/daily_employee_row.dart';
import '../domain/report.dart';
import '../domain/shift_employee_row.dart';
import '../domain/undetected_employee_row.dart';
import '../providers/detail_provider.dart';

class ReportExportService {
  // -------------------------------------------------------------------------
  // Main screen: list-only exports (all included employees, no period details)
  // -------------------------------------------------------------------------

  Future<String?> exportShift({
    required Report report,
    required List<ShiftEmployeeRow> includedRows,
    required String roundingMode,
  }) async {
    final start = _isoLabel(report.rangeStart);
    final end = _isoLabel(report.rangeEnd);
    final fileName = 'تقرير_مناوبة_${start}_$end.xlsx';

    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ تقرير المناوبة',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      lockParentWindow: true,
    );
    if (path == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'المناوبة');
    final sheet = excel['المناوبة'];

    sheet.appendRow([TextCellValue('تقرير المناوبة')]);
    sheet.appendRow([
      TextCellValue('نطاق التاريخ:'),
      TextCellValue(
          '${_fmtDate(report.rangeStart)} - ${_fmtDate(report.rangeEnd)}'),
    ]);
    sheet.appendRow([
      TextCellValue('الموظفون المحتسبون:'),
      IntCellValue(includedRows.length),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي الساعات الإضافية:'),
      TextCellValue(_fmt(
        includedRows.fold(0, (s, r) => s + r.overtimeMinutes),
        roundingMode,
      )),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('القسم'),
      TextCellValue('ساعات إضافية'),
    ]);
    for (final row in includedRows) {
      sheet.appendRow([
        TextCellValue(row.employeeName),
        TextCellValue(row.department),
        TextCellValue(_fmt(row.overtimeMinutes, roundingMode)),
      ]);
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String?> exportDaily({
    required Report report,
    required List<DailyEmployeeRow> includedRows,
    required String roundingMode,
  }) async {
    final start = _isoLabel(report.rangeStart);
    final end = _isoLabel(report.rangeEnd);
    final fileName = 'تقرير_صباحي_${start}_$end.xlsx';

    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ تقرير الدوام الصباحي',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      lockParentWindow: true,
    );
    if (path == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'الصباحي');
    final sheet = excel['الصباحي'];

    sheet.appendRow([TextCellValue('تقرير الدوام الصباحي')]);
    sheet.appendRow([
      TextCellValue('نطاق التاريخ:'),
      TextCellValue(
          '${_fmtDate(report.rangeStart)} - ${_fmtDate(report.rangeEnd)}'),
    ]);
    sheet.appendRow([
      TextCellValue('الموظفون المحتسبون:'),
      IntCellValue(includedRows.length),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي الساعات الإضافية:'),
      TextCellValue(_fmt(
        includedRows.fold(0, (s, r) => s + r.totalOvertimeMinutes),
        roundingMode,
      )),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('القسم'),
      TextCellValue('وقت إضافي عطلة'),
      TextCellValue('وقت إضافي دوام'),
      TextCellValue('الإجمالي'),
    ]);
    for (final row in includedRows) {
      sheet.appendRow([
        TextCellValue(row.employeeName),
        TextCellValue(row.department),
        TextCellValue(row.offOvertimeMinutes > 0
            ? _fmt(row.offOvertimeMinutes, roundingMode)
            : '---'),
        TextCellValue(row.regularOvertimeMinutes > 0
            ? _fmt(row.regularOvertimeMinutes, roundingMode)
            : '---'),
        TextCellValue(_fmt(row.totalOvertimeMinutes, roundingMode)),
      ]);
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  // -------------------------------------------------------------------------
  // Detail screen: single-employee exports (full period breakdown)
  // -------------------------------------------------------------------------

  Future<String?> exportShiftEmployee({
    required DetailState state,
    required int baselineHours,
    required int ceilingHours,
  }) async {
    final name = state.employeeName;
    final start = _isoLabel(state.reportRangeStart);
    final end = _isoLabel(state.reportRangeEnd);
    final fileName = 'تفاصيل_مناوبة_${name}_${start}_$end.xlsx';

    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ تفاصيل موظف المناوبة',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      lockParentWindow: true,
    );
    if (path == null) return null;

    final periods = state.shiftPeriods;
    final totalAttendanceMin =
        periods.fold(0, (s, p) => s + p.totalAttendanceDuration);
    final totalHoursCounted = periods.fold(0, (s, p) => s + p.hoursCounted);
    final validDays = periods.where((p) => p.isValid).length;
    final overtime =
        max(0, min(totalHoursCounted, ceilingHours) - baselineHours);

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'تفاصيل المناوبة');
    final sheet = excel['تفاصيل المناوبة'];

    sheet.appendRow([TextCellValue('تفاصيل موظف المناوبة')]);
    sheet.appendRow([TextCellValue('الموظف:'), TextCellValue(name)]);
    sheet.appendRow(
        [TextCellValue('القسم:'), TextCellValue(state.department)]);
    sheet.appendRow([
      TextCellValue('الفترة:'),
      TextCellValue(
          '${_fmtDate(state.reportRangeStart)} — ${_fmtDate(state.reportRangeEnd)}'),
    ]);
    sheet.appendRow(
        [TextCellValue('أيام المناوبة الصالحة:'), IntCellValue(validDays)]);
    sheet.appendRow([
      TextCellValue('إجمالي ساعات الحضور:'),
      TextCellValue(_fmtDuration(totalAttendanceMin)),
    ]);
    sheet.appendRow([
      TextCellValue('الساعات المحتسبة:'),
      TextCellValue('$totalHoursCounted ساعة'),
    ]);
    sheet.appendRow([
      TextCellValue('الساعات الإضافية:'),
      TextCellValue('$overtime ساعة'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('تاريخ البداية'),
      TextCellValue('تاريخ النهاية'),
      TextCellValue('النقاط'),
      TextCellValue('ساعات الحضور'),
      TextCellValue('الساعات المحتسبة'),
      TextCellValue('ملاحظات'),
    ]);
    for (final p in periods) {
      final zoneSummary = p.zoneResults
          .map((z) => 'نقطة ${z.zoneIndex + 1}: ${z.isSatisfied ? "✓" : "✗"}')
          .join(' | ');
      sheet.appendRow([
        TextCellValue(p.periodDate),
        TextCellValue(p.endDate),
        TextCellValue(zoneSummary),
        TextCellValue(_fmtDuration(p.totalAttendanceDuration)),
        IntCellValue(p.hoursCounted),
        TextCellValue(p.notes.join(' - ')),
      ]);
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String?> exportDailyEmployee({
    required DetailState state,
    required String roundingMode,
  }) async {
    final name = state.employeeName;
    final start = _isoLabel(state.reportRangeStart);
    final end = _isoLabel(state.reportRangeEnd);
    final fileName = 'تفاصيل_صباحي_${name}_${start}_$end.xlsx';

    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ تفاصيل موظف الدوام الصباحي',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      lockParentWindow: true,
    );
    if (path == null) return null;

    final periods = state.dailyPeriods;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'تفاصيل الدوام الصباحي');
    final sheet = excel['تفاصيل الدوام الصباحي'];

    sheet.appendRow([TextCellValue('تفاصيل موظف الدوام الصباحي')]);
    sheet.appendRow([TextCellValue('الموظف:'), TextCellValue(name)]);
    sheet.appendRow(
        [TextCellValue('القسم:'), TextCellValue(state.department)]);
    sheet.appendRow([
      TextCellValue('الفترة:'),
      TextCellValue(
          '${_fmtDate(state.reportRangeStart)} — ${_fmtDate(state.reportRangeEnd)}'),
    ]);
    sheet.appendRow([
      TextCellValue('الوقت الإضافي الإجمالي:'),
      TextCellValue(_fmt(state.totalOvertimeMinutes, roundingMode)),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('اليوم'),
      TextCellValue('نوع اليوم'),
      TextCellValue('الدخول'),
      TextCellValue('الخروج'),
      TextCellValue('ساعات الحضور'),
      TextCellValue('الوقت الإضافي'),
      TextCellValue('ملاحظات'),
    ]);
    for (final p in periods) {
      final ts = p.timestamps;
      final entry = ts.isNotEmpty ? _timeOnly(ts.first) : '';
      final exit = ts.length > 1 ? _timeOnly(ts.last) : '';
      final dayTypeLabel = p.dayType == 'off' ? 'عطلة' : 'دوام';
      sheet.appendRow([
        TextCellValue(p.date),
        TextCellValue(p.weekday),
        TextCellValue(dayTypeLabel),
        TextCellValue(entry),
        TextCellValue(exit),
        TextCellValue(_fmtDuration(p.totalAttendanceDuration)),
        TextCellValue(_fmt(p.overtimeMinutes, roundingMode)),
        TextCellValue(p.notes.join(' - ')),
      ]);
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String?> exportUndetectedList({
    required Report report,
    required List<UndetectedEmployeeRow> rows,
  }) async {
    final start = _isoLabel(report.rangeStart);
    final end = _isoLabel(report.rangeEnd);
    final fileName = 'تقرير_غير_محددين_${start}_$end.xlsx';

    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ قائمة الموظفين غير المحددين',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      lockParentWindow: true,
    );
    if (path == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'غير محددين');
    final sheet = excel['غير محددين'];

    sheet.appendRow([TextCellValue('قائمة الموظفين غير المحددين')]);
    sheet.appendRow([
      TextCellValue('نطاق التاريخ:'),
      TextCellValue(
          '${_fmtDate(report.rangeStart)} - ${_fmtDate(report.rangeEnd)}'),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي الموظفين:'),
      IntCellValue(rows.length),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('القسم'),
      TextCellValue('سبب عدم الكشف'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.employeeName),
        TextCellValue(row.department),
        TextCellValue(row.failureReason),
      ]);
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String?> exportUndetectedEmployee({
    required DetailState state,
  }) async {
    final name = state.employeeName;
    final start = _isoLabel(state.reportRangeStart);
    final end = _isoLabel(state.reportRangeEnd);
    final fileName = 'تفاصيل_غير_محدد_${name}_${start}_$end.xlsx';

    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ تفاصيل الموظف غير المحدد',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      lockParentWindow: true,
    );
    if (path == null) return null;

    final periods = state.undetectedPeriods;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'تفاصيل غير محدد');
    final sheet = excel['تفاصيل غير محدد'];

    sheet.appendRow([TextCellValue('تفاصيل الموظف غير المحدد')]);
    sheet.appendRow([TextCellValue('الموظف:'), TextCellValue(name)]);
    sheet.appendRow(
        [TextCellValue('القسم:'), TextCellValue(state.department)]);
    sheet.appendRow([
      TextCellValue('الفترة:'),
      TextCellValue(
          '${_fmtDate(state.reportRangeStart)} — ${_fmtDate(state.reportRangeEnd)}'),
    ]);
    sheet.appendRow(
        [TextCellValue('سبب عدم الكشف:'), TextCellValue(state.failureReason)]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('اليوم'),
      TextCellValue('البصمات'),
    ]);
    for (final p in periods) {
      final stamps = p.timestamps.map(_timeOnly).join(' | ');
      sheet.appendRow([
        TextCellValue(p.date),
        TextCellValue(p.weekday),
        TextCellValue(stamps),
      ]);
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  // ---- helpers ----

  String _fmt(int minutes, String mode) {
    int rounded = minutes;
    switch (mode) {
      case 'quarter':
        rounded = ((minutes / 15).ceil() * 15);
      case 'half':
        rounded = ((minutes / 30).ceil() * 30);
      case 'hour':
        rounded = ((minutes / 60).ceil() * 60);
    }
    final h = rounded ~/ 60;
    final m = rounded % 60;
    if (m == 0) return '$h ساعة';
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h ساعة';
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _timeOnly(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _isoLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
