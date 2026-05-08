import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/domain/day_type.dart';
import '../../../shared/domain/report_data.dart';

class ReportExportService {
  Future<String> exportReport({
    required ReportData report,
    required String roundingMode,
    required int baselineHours,
    required int ceilingHours,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildSummarySheet(excel, report, roundingMode);
    _buildDetailSheet(excel, report, roundingMode, baselineHours, ceilingHours);

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      throw Exception('لا يمكن الوصول إلى مجلد التنزيلات');
    }

    final df = DateFormat('yyyyMMdd');
    final fileName =
        'report_${df.format(report.summary.rangeStart)}_${df.format(report.summary.rangeEnd)}.xlsx';
    final file = File('${downloadsDir.path}/$fileName');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل في إنشاء ملف Excel');

    await file.writeAsBytes(bytes);
    return file.path;
  }

  void _buildSummarySheet(
      Excel excel, ReportData report, String roundingMode) {
    const sheetName = 'ملخص التقرير';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    final dateFormat = DateFormat('yyyy/MM/dd');
    final summary = report.summary;

    sheet.appendRow([
      TextCellValue('الفترة'),
      TextCellValue(
          '${dateFormat.format(summary.rangeStart)} — ${dateFormat.format(summary.rangeEnd)}'),
    ]);
    sheet.appendRow([
      TextCellValue('إجمالي الموظفين'),
      IntCellValue(summary.totalEmployees),
    ]);
    sheet.appendRow([
      TextCellValue('وقت إضافي مناوبة'),
      TextCellValue('${summary.totalShiftOvertimeHours} س'),
    ]);
    sheet.appendRow([
      TextCellValue('وقت إضافي عادي'),
      TextCellValue(
          _formatMinutes(summary.totalDailyOvertimeMinutes, roundingMode)),
    ]);
    sheet.appendRow([
      TextCellValue('وقت إضافي عطل'),
      TextCellValue(
          _formatMinutes(summary.totalHolidayOvertimeMinutes, roundingMode)),
    ]);
    if (summary.unmatchedEmployeeCount > 0) {
      sheet.appendRow([
        TextCellValue('غير موجودين'),
        IntCellValue(summary.unmatchedEmployeeCount),
      ]);
    }

    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('موظفو الدوام الصباحي')]);
    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('القسم'),
      TextCellValue('ساعات عادية'),
      TextCellValue('ساعات عطلة'),
      TextCellValue('المجموع'),
    ]);

    final matchedDaily = report.dailyResults.where((r) => !r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final unmatchedDaily = report.dailyResults.where((r) => r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final r in [...matchedDaily, ...unmatchedDaily]) {
      if (r.isUnmatched) {
        sheet.appendRow([
          TextCellValue(r.name),
          TextCellValue(r.department),
          TextCellValue('—'),
          TextCellValue('—'),
          TextCellValue(r.notes ?? ''),
        ]);
      } else {
        sheet.appendRow([
          TextCellValue(r.name),
          TextCellValue(r.department),
          TextCellValue(_formatMinutes(r.totalRegularOvertimeMinutes, roundingMode)),
          TextCellValue(_formatMinutes(r.totalHolidayOvertimeMinutes, roundingMode)),
          TextCellValue(_formatMinutes(
              r.totalRegularOvertimeMinutes + r.totalHolidayOvertimeMinutes,
              roundingMode)),
        ]);
      }
    }

    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('موظفو الدوام بالمناوبة')]);
    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('القسم'),
      TextCellValue('ساعات إضافية'),
    ]);

    final matchedShift = report.shiftResults.where((r) => !r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final unmatchedShift = report.shiftResults.where((r) => r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final r in [...matchedShift, ...unmatchedShift]) {
      if (r.isUnmatched) {
        sheet.appendRow([
          TextCellValue(r.name),
          TextCellValue(r.department),
          TextCellValue(r.notes ?? ''),
        ]);
      } else {
        sheet.appendRow([
          TextCellValue(r.name),
          TextCellValue(r.department),
          TextCellValue('${r.totalOvertimeHours} س'),
        ]);
      }
    }
  }

  void _buildDetailSheet(Excel excel, ReportData report, String roundingMode,
      int baselineHours, int ceilingHours) {
    const sheetName = 'تفاصيل الموظفين';
    final sheet = excel[sheetName];

    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('H:mm');
    final shortDateFormat = DateFormat('dd/MM');

    final matchedDaily = report.dailyResults.where((r) => !r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final matchedShift = report.shiftResults.where((r) => !r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    bool firstSection = true;

    for (final r in matchedDaily) {
      if (!firstSection) sheet.appendRow([]);
      firstSection = false;

      final total =
          r.totalRegularOvertimeMinutes + r.totalHolidayOvertimeMinutes;

      sheet.appendRow([TextCellValue(r.name)]);
      sheet.appendRow([
        TextCellValue('القسم: ${r.department}'),
        TextCellValue('نوع التوظيف: صباحي'),
        TextCellValue(
            'الفترة: ${dateFormat.format(report.summary.rangeStart)} — ${dateFormat.format(report.summary.rangeEnd)}'),
        TextCellValue(
            'وقت إضافي عادي: ${_formatMinutes(r.totalRegularOvertimeMinutes, roundingMode)}'),
        TextCellValue(
            'وقت إضافي عطل: ${_formatMinutes(r.totalHolidayOvertimeMinutes, roundingMode)}'),
        TextCellValue('الإجمالي: ${_formatMinutes(total, roundingMode)}'),
      ]);
      sheet.appendRow([
        TextCellValue('التاريخ'),
        TextCellValue('اليوم'),
        TextCellValue('نوع اليوم'),
        TextCellValue('الدخول'),
        TextCellValue('البصمات'),
        TextCellValue('الخروج'),
        TextCellValue('ساعات الحضور'),
        TextCellValue('الوقت الإضافي'),
        TextCellValue('ملاحظات'),
      ]);

      for (final p in r.periods) {
        final firstTs =
            p.timestamps.isNotEmpty ? timeFormat.format(p.timestamps.first) : '—';
        final lastTs =
            p.timestamps.isNotEmpty ? timeFormat.format(p.timestamps.last) : '—';
        final middle = p.timestamps.length > 2
            ? p.timestamps
                .sublist(1, p.timestamps.length - 1)
                .map(timeFormat.format)
                .join(', ')
            : '';
        final durationH = p.totalAttendanceDuration ~/ 60;
        final durationM = p.totalAttendanceDuration % 60;
        final durationText =
            durationM == 0 ? '$durationH س' : '$durationH س $durationM د';

        sheet.appendRow([
          TextCellValue(shortDateFormat.format(p.date)),
          TextCellValue(p.weekday),
          TextCellValue(_dayTypeLabel(p.dayType)),
          TextCellValue(firstTs),
          TextCellValue(middle),
          TextCellValue(lastTs),
          TextCellValue(durationText),
          TextCellValue(
              p.isValid ? _formatMinutes(p.overtimeMinutes, roundingMode) : '—'),
          TextCellValue(p.notes ?? ''),
        ]);
      }
    }

    for (final r in matchedShift) {
      if (!firstSection) sheet.appendRow([]);
      firstSection = false;

      final totalActualMinutes =
          r.periods.fold(0, (sum, p) => sum + p.totalAttendanceDuration);
      final totalCounted =
          r.periods.fold(0, (sum, p) => sum + p.hoursCounted);
      final cappedCounted = totalCounted.clamp(0, ceilingHours);
      final overtime = (cappedCounted - baselineHours).clamp(0, ceilingHours);
      final validDays = r.periods.where((p) => p.isValid).length;
      final totalActualH = totalActualMinutes ~/ 60;
      final totalActualM = totalActualMinutes % 60;
      final actualText =
          totalActualM == 0 ? '$totalActualH س' : '$totalActualH س $totalActualM د';

      sheet.appendRow([TextCellValue(r.name)]);
      sheet.appendRow([
        TextCellValue('القسم: ${r.department}'),
        TextCellValue('نوع التوظيف: مناوب'),
        TextCellValue(
            'الفترة: ${dateFormat.format(report.summary.rangeStart)} — ${dateFormat.format(report.summary.rangeEnd)}'),
        TextCellValue('أيام مناوبة صالحة: $validDays'),
        TextCellValue('إجمالي ساعات الحضور الفعلية: $actualText'),
        TextCellValue('الساعات المحتسبة: $totalCounted س'),
        TextCellValue('الوقت الإضافي: $overtime س'),
      ]);
      sheet.appendRow([
        TextCellValue('تاريخ البداية'),
        TextCellValue('تاريخ النهاية'),
        TextCellValue('بصمة البداية'),
        TextCellValue('نقاط التحقق'),
        TextCellValue('ساعات الحضور'),
        TextCellValue('الساعات المحتسبة'),
        TextCellValue('ملاحظات'),
      ]);

      for (final p in r.periods) {
        final zonesText = p.zoneResults.asMap().entries.map((e) {
          final idx = e.key + 1;
          final z = e.value;
          final satisfied = z.isSatisfied ? '✓' : '✗';
          final times = z.timestamps.isEmpty
              ? '—'
              : z.timestamps.map(timeFormat.format).join(', ');
          return 'نقطة $idx: $times $satisfied';
        }).join(' | ');

        final durationH = p.totalAttendanceDuration ~/ 60;
        final durationM = p.totalAttendanceDuration % 60;
        final durationText =
            durationM == 0 ? '$durationH س' : '$durationH س $durationM د';

        sheet.appendRow([
          TextCellValue(shortDateFormat.format(p.startDate)),
          TextCellValue(shortDateFormat.format(p.endDate)),
          TextCellValue(timeFormat.format(p.anchorTimestamp)),
          TextCellValue(zonesText),
          TextCellValue(durationText),
          TextCellValue('${p.hoursCounted} س'),
          TextCellValue(p.notes ?? ''),
        ]);
      }
    }
  }

  String _formatMinutes(int rawMinutes, String roundingMode) {
    final rounded = _applyRounding(rawMinutes, roundingMode);
    final hours = rounded ~/ 60;
    final minutes = rounded % 60;
    if (minutes == 0) return '$hours س';
    return '$hours س $minutes د';
  }

  int _applyRounding(int minutes, String mode) {
    return switch (mode) {
      'quarter' => ((minutes / 15).round() * 15),
      'half' => ((minutes / 30).round() * 30),
      'hour' => ((minutes / 60).round() * 60),
      _ => minutes,
    };
  }

  String _dayTypeLabel(DayType type) => switch (type) {
        DayType.regular => 'عادي',
        DayType.holiday => 'عطلة',
        DayType.weekend => 'عطلة أسبوعية',
      };
}
