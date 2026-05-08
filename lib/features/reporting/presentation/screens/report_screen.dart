import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/domain/daily_employee_result.dart';
import '../../../../shared/domain/report_data.dart';
import '../../../../shared/domain/shift_employee_result.dart';
import '../providers/report_providers.dart';
import '../providers/settings_providers.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final int reportId;

  const ReportScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(widget.reportId));
    final settingsAsync = ref.watch(settingsProvider);
    final exportState = ref.watch(reportExportProvider);

    ref.listen<ReportExportState>(reportExportProvider, (_, next) {
      if (next.successPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم الحفظ في: ${next.successPath}')),
        );
        ref.read(reportExportProvider.notifier).clearResult();
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(reportExportProvider.notifier).clearResult();
      }
    });

    return reportAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('التقرير')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('التقرير')),
        body: Center(
          child: Text('خطأ في تحميل التقرير',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ),
      data: (report) {
        if (report == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('التقرير')),
            body: const Center(child: Text('التقرير غير موجود')),
          );
        }
        final settings = settingsAsync.value;
        final roundingMode = settings?.roundingMode ?? 'none';
        return _ReportBody(
          report: report,
          tabController: _tabController,
          roundingMode: roundingMode,
          reportId: widget.reportId,
          isExporting: exportState.isExporting,
          onExport: settings == null
              ? null
              : () => ref.read(reportExportProvider.notifier).export(
                    report: report,
                    settings: settings,
                  ),
        );
      },
    );
  }
}

class _ReportBody extends StatelessWidget {
  final ReportData report;
  final TabController tabController;
  final String roundingMode;
  final int reportId;
  final bool isExporting;
  final VoidCallback? onExport;

  const _ReportBody({
    required this.report,
    required this.tabController,
    required this.roundingMode,
    required this.reportId,
    required this.isExporting,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${dateFormat.format(summary.rangeStart)} — ${dateFormat.format(summary.rangeEnd)}'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'الدوام الصباحي'),
            Tab(text: 'الدوام بالمناوبة'),
          ],
        ),
      ),
      body: Column(
        children: [
          _ReportHeader(
            summary: summary,
            roundingMode: roundingMode,
          ),
          _ActionBar(isExporting: isExporting, onExport: onExport),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _DailyTab(
                  results: report.dailyResults,
                  roundingMode: roundingMode,
                  reportId: reportId,
                ),
                _ShiftTab(
                  results: report.shiftResults,
                  reportId: reportId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool isExporting;
  final VoidCallback? onExport;

  const _ActionBar({required this.isExporting, this.onExport});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: isExporting ? null : onExport,
            icon: isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            label: Text(isExporting ? 'جارٍ التصدير...' : 'تصدير Excel'),
          ),
        ],
      ),
    );
  }
}

// ── Report Header ─────────────────────────────────────────────────────────────

class _ReportHeader extends StatelessWidget {
  final ReportListItem summary;
  final String roundingMode;

  const _ReportHeader({required this.summary, required this.roundingMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 24,
        runSpacing: 4,
        children: [
          _HeaderChip(
              label: 'إجمالي الموظفين',
              value: '${summary.totalEmployees}'),
          _HeaderChip(
              label: 'وقت إضافي مناوبة',
              value: '${summary.totalShiftOvertimeHours} س'),
          _HeaderChip(
              label: 'وقت إضافي عادي',
              value: _fmtMinutes(
                  summary.totalDailyOvertimeMinutes, roundingMode)),
          _HeaderChip(
              label: 'وقت إضافي عطل',
              value: _fmtMinutes(
                  summary.totalHolidayOvertimeMinutes, roundingMode)),
          if (summary.unmatchedEmployeeCount > 0)
            _HeaderChip(
              label: 'غير موجودين',
              value: '${summary.unmatchedEmployeeCount}',
              isWarning: true,
            ),
        ],
      ),
    );
  }

  String _fmtMinutes(int minutes, String mode) =>
      formatMinutes(minutes, mode);
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _HeaderChip(
      {required this.label, required this.value, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isWarning ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

// ── Daily Tab ─────────────────────────────────────────────────────────────────

class _DailyTab extends StatelessWidget {
  final List<DailyEmployeeResult> results;
  final String roundingMode;
  final int reportId;

  const _DailyTab({
    required this.results,
    required this.roundingMode,
    required this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('لا يوجد موظفون بنظام الدوام الصباحي'));
    }

    final matched = results.where((r) => !r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final unmatched = results.where((r) => r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final sorted = [...matched, ...unmatched];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('اسم الموظف')),
            DataColumn(label: Text('القسم')),
            DataColumn(label: Text('ساعات عادية')),
            DataColumn(label: Text('ساعات عطلة')),
            DataColumn(label: Text('المجموع')),
          ],
          rows: sorted.map((r) {
            final isUnmatched = r.isUnmatched;
            final regular = formatMinutes(r.totalRegularOvertimeMinutes, roundingMode);
            final holiday = formatMinutes(r.totalHolidayOvertimeMinutes, roundingMode);
            final total = formatMinutes(
                r.totalRegularOvertimeMinutes + r.totalHolidayOvertimeMinutes,
                roundingMode);

            return DataRow(
              color: isUnmatched
                  ? WidgetStateProperty.all(Colors.red.shade50)
                  : null,
              onSelectChanged: isUnmatched
                  ? null
                  : (_) => context.goNamed(
                        'detail',
                        pathParameters: {
                          'reportId': reportId.toString(),
                          'employeeName': r.name,
                        },
                      ),
              cells: [
                DataCell(Text(r.name)),
                DataCell(Text(r.department)),
                DataCell(Text(isUnmatched ? '—' : regular)),
                DataCell(Text(isUnmatched ? '—' : holiday)),
                DataCell(isUnmatched
                    ? Text(
                        r.notes ?? '',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12),
                      )
                    : Text(total)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Shift Tab ─────────────────────────────────────────────────────────────────

class _ShiftTab extends StatelessWidget {
  final List<ShiftEmployeeResult> results;
  final int reportId;

  const _ShiftTab({required this.results, required this.reportId});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('لا يوجد موظفون بنظام المناوبة'));
    }

    final matched = results.where((r) => !r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final unmatched = results.where((r) => r.isUnmatched).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final sorted = [...matched, ...unmatched];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('اسم الموظف')),
            DataColumn(label: Text('القسم')),
            DataColumn(label: Text('ساعات إضافية')),
          ],
          rows: sorted.map((r) {
            final isUnmatched = r.isUnmatched;

            return DataRow(
              color: isUnmatched
                  ? WidgetStateProperty.all(Colors.red.shade50)
                  : null,
              onSelectChanged: isUnmatched
                  ? null
                  : (_) => context.goNamed(
                        'detail',
                        pathParameters: {
                          'reportId': reportId.toString(),
                          'employeeName': r.name,
                        },
                      ),
              cells: [
                DataCell(Text(r.name)),
                DataCell(Text(r.department)),
                DataCell(isUnmatched
                    ? Text(
                        r.notes ?? '',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12),
                      )
                    : Text('${r.totalOvertimeHours} س')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Rounding utility (shared by report + detail screens) ──────────────────────

String formatMinutes(int rawMinutes, String roundingMode) {
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
