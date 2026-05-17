import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../data/reports_repository.dart';
import '../domain/daily_employee_row.dart';
import '../domain/report.dart';
import '../domain/shift_employee_row.dart';

class ReportExportService {
  Future<String?> exportShift({
    required Report report,
    required List<ShiftEmployeeRow> includedRows,
    required ReportsRepository repo,
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

    // Summary section
    sheet.appendRow([TextCellValue('تقرير المناوبة')]);
    sheet.appendRow([
      TextCellValue('نطاق التاريخ:'),
      TextCellValue('${_fmtDate(report.rangeStart)} - ${_fmtDate(report.rangeEnd)}'),
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

    // Employee table header
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
    sheet.appendRow([TextCellValue('')]);

    // Period details
    sheet.appendRow([TextCellValue('تفاصيل الفترات')]);
    for (final row in includedRows) {
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('الموظف:'), TextCellValue(row.employeeName)]);
      sheet.appendRow([
        TextCellValue('تاريخ البداية'),
        TextCellValue('تاريخ النهاية'),
        TextCellValue('ساعات الحضور'),
        TextCellValue('الساعات المحتسبة'),
        TextCellValue('المناطق'),
        TextCellValue('ملاحظات'),
      ]);
      final periods = await repo.loadShiftPeriods(row.id);
      for (final p in periods) {
        final zoneData = jsonDecode(p['zone_data'] as String) as List;
        final zoneSummary = zoneData
            .map((z) {
              final satisfied = z['isSatisfied'] as bool;
              final idx = (z['zoneIndex'] as int) + 1;
              return 'نقطة $idx: ${satisfied ? "✓" : "✗"}';
            })
            .join(' | ');
        final duration = p['total_attendance_duration'] as int;
        final counted = p['hours_counted'] as int;
        sheet.appendRow([
          TextCellValue(p['period_date'] as String),
          TextCellValue(p['end_date'] as String),
          TextCellValue(_fmtDuration(duration)),
          IntCellValue(counted),
          TextCellValue(zoneSummary),
          TextCellValue((p['notes'] as String?) ?? ''),
        ]);
      }
    }

    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String?> exportDaily({
    required Report report,
    required List<DailyEmployeeRow> includedRows,
    required ReportsRepository repo,
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

    // Summary section
    sheet.appendRow([TextCellValue('تقرير الدوام الصباحي')]);
    sheet.appendRow([
      TextCellValue('نطاق التاريخ:'),
      TextCellValue('${_fmtDate(report.rangeStart)} - ${_fmtDate(report.rangeEnd)}'),
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

    // Employee table header
    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('القسم'),
      TextCellValue('المجموع'),
    ]);
    for (final row in includedRows) {
      sheet.appendRow([
        TextCellValue(row.employeeName),
        TextCellValue(row.department),
        TextCellValue(_fmt(row.totalOvertimeMinutes, roundingMode)),
      ]);
    }
    sheet.appendRow([TextCellValue('')]);

    // Period details
    sheet.appendRow([TextCellValue('تفاصيل الفترات')]);
    for (final row in includedRows) {
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('الموظف:'), TextCellValue(row.employeeName)]);
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
      final periods = await repo.loadDailyPeriods(row.id);
      for (final p in periods) {
        final timestamps =
            (jsonDecode(p['all_timestamps'] as String) as List).cast<String>();
        final first = timestamps.isNotEmpty ? _timeOnly(DateTime.parse(timestamps.first)) : '';
        final last =
            timestamps.length > 1 ? _timeOnly(DateTime.parse(timestamps.last)) : '';
        final dayType = p['day_type'] as String == 'off' ? 'عطلة' : 'عادي';
        sheet.appendRow([
          TextCellValue(p['date'] as String),
          TextCellValue(p['weekday'] as String),
          TextCellValue(dayType),
          TextCellValue(first),
          TextCellValue(last),
          TextCellValue(_fmtDuration(p['total_attendance_duration'] as int)),
          TextCellValue(_fmt(p['overtime_minutes'] as int, roundingMode)),
          TextCellValue((p['notes'] as String?) ?? ''),
        ]);
      }
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
