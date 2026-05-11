import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/domain/daily_employee_result.dart';
import '../../../../shared/domain/day_type.dart';
import '../../../../shared/domain/report_data.dart';
import '../../../../shared/domain/shift_employee_result.dart';
import '../providers/report_providers.dart';
import '../providers/settings_providers.dart';
import 'report_screen.dart' show formatMinutes;

class DetailScreen extends ConsumerWidget {
  final int reportId;
  final String employeeName;

  const DetailScreen({
    super.key,
    required this.reportId,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportProvider(reportId));
    final settingsAsync = ref.watch(settingsProvider);

    return reportAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('التفاصيل')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('التفاصيل')),
        body: const Center(child: Text('خطأ في تحميل البيانات')),
      ),
      data: (report) {
        if (report == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('التفاصيل')),
            body: const Center(child: Text('لم يتم العثور على التقرير')),
          );
        }

        final decodedName = employeeName;
        final roundingMode = settingsAsync.value?.roundingMode ?? 'none';
        final settings = settingsAsync.value;

        final dailyResult = report.dailyResults
            .where((r) => r.name == decodedName)
            .firstOrNull;

        if (dailyResult != null) {
          return _DailyDetailScreen(
            result: dailyResult,
            reportSummary: report.summary,
            roundingMode: roundingMode,
          );
        }

        final shiftResult = report.shiftResults
            .where((r) => r.name == decodedName)
            .firstOrNull;

        if (shiftResult != null) {
          return _ShiftDetailScreen(
            result: shiftResult,
            reportSummary: report.summary,
            baselineHours: settings?.shiftBaselineHours ?? 154,
            ceilingHours: settings?.shiftCeilingHours ?? 192,
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('التفاصيل')),
          body: const Center(child: Text('لم يتم العثور على الموظف')),
        );
      },
    );
  }
}

// ── Daily Detail ──────────────────────────────────────────────────────────────

class _DailyDetailScreen extends StatelessWidget {
  final DailyEmployeeResult result;
  final ReportListItem reportSummary;
  final String roundingMode;

  const _DailyDetailScreen({
    required this.result,
    required this.reportSummary,
    required this.roundingMode,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final total = result.totalRegularOvertimeMinutes +
        result.totalHolidayOvertimeMinutes;

    return Scaffold(
      appBar: AppBar(title: Text(result.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EmployeeHeader(children: [
              _InfoRow('القسم', result.department),
              _InfoRow('نوع التوظيف', 'صباحي'),
              _InfoRow(
                  'الفترة',
                  '${dateFormat.format(reportSummary.rangeStart)}'
                      ' — ${dateFormat.format(reportSummary.rangeEnd)}'),
              _InfoRow('وقت إضافي عادي',
                  formatMinutes(result.totalRegularOvertimeMinutes, roundingMode)),
              _InfoRow('وقت إضافي عطل',
                  formatMinutes(result.totalHolidayOvertimeMinutes, roundingMode)),
              _InfoRow('الإجمالي', formatMinutes(total, roundingMode)),
            ]),
            const SizedBox(height: 8),
            if (result.periods.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد بيانات'),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Center(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('اليوم')),
                          DataColumn(label: Text('نوع اليوم')),
                          DataColumn(label: Text('الدخول')),
                          DataColumn(label: Text('البصمات')),
                          DataColumn(label: Text('الخروج')),
                          DataColumn(label: Text('ساعات الحضور')),
                          DataColumn(label: Text('الوقت الإضافي')),
                          DataColumn(label: Text('ملاحظات')),
                        ],
                        rows: result.periods.map((p) {
                          final tf = DateFormat('H:mm', 'ar');
                          final firstTs =
                              p.timestamps.isNotEmpty ? tf.format(p.timestamps.first) : '—';
                          final lastTs =
                              p.timestamps.isNotEmpty ? tf.format(p.timestamps.last) : '—';
                          final middle = p.timestamps.length > 2
                              ? p.timestamps
                                  .sublist(1, p.timestamps.length - 1)
                                  .map(tf.format)
                                  .join('\n')
                              : '';
                          final durationH = p.totalAttendanceDuration ~/ 60;
                          final durationM = p.totalAttendanceDuration % 60;
                          final durationText =
                              durationM == 0 ? '$durationH س' : '$durationH س $durationM د';

                          return DataRow(
                            color: WidgetStateProperty.all(
                              p.isValid ? Colors.white : Colors.red.shade50,
                            ),
                            cells: [
                              DataCell(Text(DateFormat('dd/MM').format(p.date))),
                              DataCell(Text(p.weekday)),
                              DataCell(Text(_dayTypeLabel(p.dayType))),
                              DataCell(Text(firstTs)),
                              DataCell(Text(middle, style: const TextStyle(fontSize: 12))),
                              DataCell(Text(lastTs)),
                              DataCell(Text(durationText)),
                              DataCell(Text(p.isValid
                                  ? formatMinutes(p.overtimeMinutes, roundingMode)
                                  : '—')),
                              DataCell(Text(p.notes ?? '')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dayTypeLabel(DayType type) => switch (type) {
        DayType.regular => 'عادي',
        DayType.holiday => 'عطلة',
        DayType.weekend => 'عطلة أسبوعية',
      };
}

// ── Shift Detail ──────────────────────────────────────────────────────────────

class _ShiftDetailScreen extends StatelessWidget {
  final ShiftEmployeeResult result;
  final ReportListItem reportSummary;
  final int baselineHours;
  final int ceilingHours;

  const _ShiftDetailScreen({
    required this.result,
    required this.reportSummary,
    required this.baselineHours,
    required this.ceilingHours,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final validDays = result.periods.where((p) => p.isValid).length;
    final totalActualMinutes = result.periods.fold(
        0, (sum, p) => sum + p.totalAttendanceDuration);
    final totalCounted =
        result.periods.fold(0, (sum, p) => sum + p.hoursCounted);
    final cappedCounted = totalCounted.clamp(0, ceilingHours);
    final overtime = (cappedCounted - baselineHours).clamp(0, ceilingHours);
    final totalActualH = totalActualMinutes ~/ 60;
    final totalActualM = totalActualMinutes % 60;

    return Scaffold(
      appBar: AppBar(title: Text(result.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EmployeeHeader(children: [
              _InfoRow('القسم', result.department),
              _InfoRow('نوع التوظيف', 'مناوب'),
              _InfoRow(
                  'الفترة',
                  '${dateFormat.format(reportSummary.rangeStart)}'
                      ' — ${dateFormat.format(reportSummary.rangeEnd)}'),
              _InfoRow('أيام مناوبة صالحة', '$validDays'),
              _InfoRow(
                  'إجمالي ساعات الحضور الفعلية',
                  totalActualM == 0
                      ? '$totalActualH س'
                      : '$totalActualH س $totalActualM د'),
              _InfoRow('الساعات المحتسبة', '$totalCounted س'),
              _InfoRow('الوقت الإضافي', '$overtime س'),
            ]),
            const SizedBox(height: 8),
            if (result.periods.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد بيانات'),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Center(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('تاريخ البداية')),
                          DataColumn(label: Text('تاريخ النهاية')),
                          DataColumn(label: Text('بصمة البداية')),
                          DataColumn(label: Text('نقاط التحقق')),
                          DataColumn(label: Text('ساعات الحضور')),
                          DataColumn(label: Text('الساعات المحتسبة')),
                          DataColumn(label: Text('ملاحظات')),
                        ],
                        rows: result.periods.map((p) {
                          final df = DateFormat('dd/MM');
                          final tf = DateFormat('H:mm', 'ar');
                          final durationH = p.totalAttendanceDuration ~/ 60;
                          final durationM = p.totalAttendanceDuration % 60;
                          final durationText =
                              durationM == 0 ? '$durationH س' : '$durationH س $durationM د';

                          final zonesText = p.zoneResults.asMap().entries.map((e) {
                            final idx = e.key + 1;
                            final z = e.value;
                            final satisfied = z.isSatisfied ? '✓' : '✗';
                            final times = z.timestamps.isEmpty
                                ? '—'
                                : z.timestamps.map(tf.format).join(', ');
                            return 'نقطة $idx: $times $satisfied';
                          }).join('\n');

                          return DataRow(
                            color: WidgetStateProperty.all(
                              p.isValid ? Colors.white : Colors.red.shade50,
                            ),
                            cells: [
                              DataCell(Text(df.format(p.startDate))),
                              DataCell(Text(df.format(p.endDate))),
                              DataCell(Text(tf.format(p.anchorTimestamp))),
                              DataCell(Text(zonesText,
                                  style: const TextStyle(fontSize: 11))),
                              DataCell(Text(durationText)),
                              DataCell(Text('${p.hoursCounted} س')),
                              DataCell(Text(p.notes ?? '')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _EmployeeHeader extends StatelessWidget {
  final List<Widget> children;
  const _EmployeeHeader({required this.children});

  @override
  Widget build(BuildContext context) {
    final bg =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      color: bg,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 24,
        runSpacing: 4,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
