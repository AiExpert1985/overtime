import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/minutes_format.dart';
import '../domain/daily_period_row.dart';
import '../domain/shift_period_row.dart';
import '../domain/undetected_period_row.dart';
import '../domain/zone_row.dart';
import '../providers/detail_provider.dart';

/// Builds the printable (A4 landscape) version of the employee Detail screen
/// and sends it to the Windows print dialog. Mirrors the screen's content;
/// the table header repeats on every page and rows never split across pages.
class DetailPrintService {
  static final _pageFormat = PdfPageFormat.a4.landscape;
  static const _fontSize = 9.0;

  /// Opens the Windows print dialog for [state]. Returns false when the
  /// dialog was cancelled.
  Future<bool> printDetail({
    required DetailState state,
    required int baselineHours,
    required int ceilingHours,
    required String roundingMode,
  }) async {
    final bytes = await buildPdf(
      state: state,
      baselineHours: baselineHours,
      ceilingHours: ceilingHours,
      roundingMode: roundingMode,
    );
    return Printing.layoutPdf(
      name: 'تفاصيل ${state.employeeName}',
      format: _pageFormat,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildPdf({
    required DetailState state,
    required int baselineHours,
    required int ceilingHours,
    required String roundingMode,
  }) async {
    final theme = await _loadTheme();
    final layout = switch (state.employeeType) {
      'shift' => _shiftLayout(state, baselineHours, ceilingHours),
      'daily' => _dailyLayout(state, roundingMode),
      _ => _undetectedLayout(state),
    };

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _titleBlock(state),
            pw.SizedBox(height: 6),
            _headerRow(layout),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (_) => [
          _summaryRow(layout.summary),
          pw.SizedBox(height: 8),
          if (layout.rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(16),
              child: pw.Center(child: pw.Text(layout.emptyMessage)),
            )
          else
            ...layout.rows,
        ],
      ),
    );
    return doc.save();
  }

  // ---- layouts ----

  _Layout _shiftLayout(DetailState state, int baselineHours, int ceilingHours) {
    final periods = state.shiftPeriods;
    final totalAttendance = periods.fold(
      0,
      (s, p) => s + p.totalAttendanceDuration,
    );
    final totalHours = periods.fold(0, (s, p) => s + p.hoursCounted);
    final overtime = max(0, min(totalHours, ceilingHours) - baselineHours);
    const flexes = [2, 2, 5, 2, 2, 3];

    return _Layout(
      columns: const [
        'تاريخ البداية',
        'تاريخ النهاية',
        '', // replaced by the checkpoint sub-titles (checkpointColumn)
        'ساعات الحضور',
        'الساعات المحتسبة',
        'ملاحظات',
      ],
      flexes: flexes,
      checkpointColumn: 2,
      summary: [
        ('أيام المناوبة الصالحة', '${periods.where((p) => p.isValid).length} يوم'),
        ('إجمالي ساعات الحضور', formatMinutes(totalAttendance)),
        ('الساعات الإضافية', formatWholeHours(overtime)),
      ],
      rows: [for (final p in periods) _shiftRow(p, flexes)],
      emptyMessage: 'لا توجد فترات محتسبة',
    );
  }

  _Layout _dailyLayout(DetailState state, String roundingMode) {
    final periods = state.dailyPeriods;
    final off = periods
        .where((p) => p.dayType == 'off')
        .fold(0, (s, p) => s + p.overtimeMinutes);
    final regular = periods
        .where((p) => p.dayType != 'off')
        .fold(0, (s, p) => s + p.overtimeMinutes);
    const flexes = [2, 2, 2, 2, 3, 2, 2, 2, 3];

    return _Layout(
      columns: const [
        'التاريخ',
        'اليوم',
        'نوع اليوم',
        'الدخول',
        'البصمات',
        'الخروج',
        'ساعات الحضور',
        'الوقت الإضافي',
        'ملاحظات',
      ],
      flexes: flexes,
      summary: [
        ('إضافي العطل', formatRoundedMinutes(off, roundingMode)),
        ('إضافي الدوام', formatRoundedMinutes(regular, roundingMode)),
        (
          'إجمالي الإضافي',
          formatRoundedMinutes(state.totalOvertimeMinutes, roundingMode),
        ),
      ],
      rows: [for (final p in periods) _dailyRow(p, flexes)],
      emptyMessage: 'لا توجد أيام',
    );
  }

  _Layout _undetectedLayout(DetailState state) {
    const flexes = [2, 2, 5];
    return _Layout(
      columns: const ['التاريخ', 'اليوم', 'البصمات'],
      flexes: flexes,
      summary: [
        ('سبب عدم الكشف', state.failureReason),
        ('أيام مسجلة', '${state.undetectedPeriods.length} يوم'),
      ],
      rows: [for (final p in state.undetectedPeriods) _undetectedRow(p, flexes)],
      emptyMessage: 'لا تتوفر بيانات للتصفح لهذا التقرير',
    );
  }

  // ---- blocks ----

  pw.Widget _titleBlock(DetailState state) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              state.employeeName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(state.department, style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'الفترة: ${_fmtDate(state.reportRangeStart)} - ${_fmtDate(state.reportRangeEnd)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'تاريخ الطباعة: ${_fmtDateTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _summaryRow(List<(String, String)> items) {
    return pw.Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    items[i].$1,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Flexible(
                    child: pw.Text(
                      items[i].$2,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _headerRow(_Layout layout) {
    final columns = layout.columns;
    final flexes = layout.flexes;
    return pw.Container(
      color: PdfColors.grey300,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            pw.Expanded(
              flex: flexes[i],
              child: i == layout.checkpointColumn
                  ? pw.Row(
                      children: [
                        _headCell('البصمة', 3),
                        _headCell('الوقت المسموح به للبصمة', 4),
                        _headCell('البصمات المتحققة', 4),
                      ],
                    )
                  : _headText(columns[i]),
            ),
        ],
      ),
    );
  }

  pw.Widget _headCell(String text, int flex) =>
      pw.Expanded(flex: flex, child: _headText(text));

  pw.Widget _headText(String text) => pw.Text(
    text,
    textAlign: pw.TextAlign.center,
    style: pw.TextStyle(fontSize: _fontSize, fontWeight: pw.FontWeight.bold),
  );

  // ---- period rows ----

  pw.Widget _shiftRow(ShiftPeriodRow p, List<int> flexes) {
    final zones = p.zoneResults;
    return _row(
      isValid: p.isValid,
      cells: [
        _cell(flexes[0], _text(_shortDate(p.periodDate))),
        _cell(flexes[1], _text(_shortDate(p.endDate))),
        pw.Expanded(
          flex: flexes[2],
          child: pw.Column(
            children: [
              for (final z in zones) _zoneRow(z, zones.length),
            ],
          ),
        ),
        _cell(flexes[3], _text(formatMinutes(p.totalAttendanceDuration))),
        _cell(flexes[4], _text('${p.hoursCounted}')),
        _cell(flexes[5], _notes(p.notes)),
      ],
    );
  }

  pw.Widget _zoneRow(ZoneRow zone, int totalZones) {
    final (start, end) = zone.approxWindow(totalZones);
    final inWindow = zone.inWindowTimestamps;
    return pw.Container(
      color: zone.isSatisfied ? null : PdfColors.red50,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: _text(_fmtTime(zone.center), bold: true),
          ),
          pw.Expanded(
            flex: 4,
            child: _text('${_fmtTime(start)} - ${_fmtTime(end)}'),
          ),
          pw.Expanded(
            flex: 4,
            child: inWindow.isEmpty
                ? _text('×', color: PdfColors.red700, bold: true)
                : _text(inWindow.map(_fmtTime).join('، ')),
          ),
        ],
      ),
    );
  }

  pw.Widget _dailyRow(DailyPeriodRow p, List<int> flexes) {
    final ts = p.timestamps;
    final intermediates = ts.length > 2 ? ts.sublist(1, ts.length - 1) : <DateTime>[];
    return _row(
      isValid: p.isValid,
      cells: [
        _cell(flexes[0], _text(_shortDate(p.date))),
        _cell(flexes[1], _text(p.weekday)),
        _cell(flexes[2], _text(p.dayType == 'off' ? 'عطلة' : 'دوام')),
        _cell(flexes[3], _text(ts.isNotEmpty ? _fmtTime(ts.first) : '—')),
        _cell(
          flexes[4],
          pw.Column(children: [for (final t in intermediates) _text(_fmtTime(t))]),
        ),
        _cell(flexes[5], _text(ts.length > 1 ? _fmtTime(ts.last) : '—')),
        _cell(flexes[6], _text(formatMinutes(p.totalAttendanceDuration))),
        _cell(flexes[7], _text(formatMinutes(p.overtimeMinutes))),
        _cell(flexes[8], _notes(p.notes)),
      ],
    );
  }

  pw.Widget _undetectedRow(UndetectedPeriodRow p, List<int> flexes) {
    return _row(
      isValid: true,
      cells: [
        _cell(flexes[0], _text(_shortDate(p.date))),
        _cell(flexes[1], _text(p.weekday)),
        _cell(
          flexes[2],
          pw.Column(children: [for (final t in p.timestamps) _text(_fmtTime(t))]),
        ),
      ],
    );
  }

  // ---- small helpers ----

  /// One table row. Wrapped so it is never split across two pages.
  pw.Widget _row({required bool isValid, required List<pw.Widget> cells}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: isValid ? null : PdfColors.red50,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.6),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: cells,
      ),
    );
  }

  pw.Widget _cell(int flex, pw.Widget child) => pw.Expanded(
    flex: flex,
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      child: pw.Center(child: child),
    ),
  );

  pw.Widget _text(String text, {bool bold = false, PdfColor? color}) {
    return pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: _fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  pw.Widget _notes(List<String> notes) =>
      pw.Column(children: [for (final n in notes) _text(n)]);

  String _fmtTime(DateTime dt) => DateFormat('h:mm a', 'ar').format(dt);

  String _shortDate(String isoDate) {
    final d = DateTime.parse(isoDate);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---- fonts ----

  /// Loads an Arabic-capable system font (Windows-only app). Tahoma first,
  /// Arial as fallback; fails fast with a clear message when neither exists.
  Future<pw.ThemeData> _loadTheme() async {
    final fontsDir = '${Platform.environment['WINDIR'] ?? r'C:\Windows'}\\Fonts';
    const candidates = [
      ('tahoma.ttf', 'tahomabd.ttf'),
      ('arial.ttf', 'arialbd.ttf'),
    ];
    for (final (regular, bold) in candidates) {
      final regularFile = File('$fontsDir\\$regular');
      final boldFile = File('$fontsDir\\$bold');
      if (!await regularFile.exists()) continue;
      final regularData = await regularFile.readAsBytes();
      final boldData = await boldFile.exists()
          ? await boldFile.readAsBytes()
          : regularData;
      return pw.ThemeData.withFont(
        base: pw.Font.ttf(ByteData.sublistView(regularData)),
        bold: pw.Font.ttf(ByteData.sublistView(boldData)),
      );
    }
    throw StateError('لم يتم العثور على خط عربي لإنشاء ملف الطباعة');
  }
}

class _Layout {
  const _Layout({
    required this.columns,
    required this.flexes,
    required this.summary,
    required this.rows,
    required this.emptyMessage,
    this.checkpointColumn,
  });

  /// Index of the column split into the three checkpoint sub-titles (shift only).
  final int? checkpointColumn;
  final List<String> columns;
  final List<int> flexes;
  final List<(String, String)> summary;
  final List<pw.Widget> rows;
  final String emptyMessage;
}
