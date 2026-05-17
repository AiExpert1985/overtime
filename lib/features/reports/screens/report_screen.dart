import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../settings/providers/settings_provider.dart';
import '../domain/daily_employee_row.dart';
import '../domain/report.dart';
import '../domain/shift_employee_row.dart';
import '../domain/undetected_employee_row.dart';
import '../providers/reports_provider.dart';
import '../services/report_export_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

String _fmtDateTime(DateTime dt) =>
    '${_fmtDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.reportId});

  final int reportId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _shiftSearch;
  late final TextEditingController _dailySearch;
  late final TextEditingController _undetectedSearch;
  bool _shiftExporting = false;
  bool _dailyExporting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _shiftSearch = TextEditingController();
    _dailySearch = TextEditingController();
    _undetectedSearch = TextEditingController();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _shiftSearch.dispose();
    _dailySearch.dispose();
    _undetectedSearch.dispose();
    super.dispose();
  }

  ReportNotifier get _notifier =>
      ref.read(reportProvider(widget.reportId).notifier);

  String get _roundingMode =>
      ref.read(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
      'quarter';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider(widget.reportId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'مناوبة'),
            Tab(text: 'صباحي'),
            Tab(text: 'غير محدَّدون'),
          ],
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('حدث خطأ أثناء التحميل: $e')),
        data: (rs) => Column(
          children: [
            _ReportHeader(report: rs.report),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ShiftTab(
                    state: rs,
                    roundingMode: _roundingMode,
                    isExporting: _shiftExporting,
                    searchController: _shiftSearch,
                    onSearch: (q) => _notifier.setShiftSearch(q),
                    onFilter: (v) => _notifier.setShiftFilter(v),
                    onToggle: (id, v) => _notifier.toggleShiftIncluded(id, v),
                    onRowTap: (id) => context.push(
                        '/reports/${widget.reportId}/detail/shift/$id'),
                    onExport: () => _doExportShift(rs),
                  ),
                  _DailyTab(
                    state: rs,
                    roundingMode: _roundingMode,
                    isExporting: _dailyExporting,
                    searchController: _dailySearch,
                    onSearch: (q) => _notifier.setDailySearch(q),
                    onFilter: (v) => _notifier.setDailyFilter(v),
                    onToggle: (id, v) => _notifier.toggleDailyIncluded(id, v),
                    onRowTap: (id) => context.push(
                        '/reports/${widget.reportId}/detail/daily/$id'),
                    onExport: () => _doExportDaily(rs),
                  ),
                  _UndetectedTab(
                    state: rs,
                    searchController: _undetectedSearch,
                    onSearch: (q) => _notifier.setUndetectedSearch(q),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doExportShift(ReportState rs) async {
    setState(() => _shiftExporting = true);
    try {
      final included = rs.shiftRows.where((r) => r.isIncluded).toList()
        ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
      final path = await ReportExportService().exportShift(
        report: rs.report,
        includedRows: included,
        repo: ref.read(reportsRepositoryProvider),
        roundingMode: _roundingMode,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم الحفظ: $path')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التصدير')),
      );
    } finally {
      if (mounted) setState(() => _shiftExporting = false);
    }
  }

  Future<void> _doExportDaily(ReportState rs) async {
    setState(() => _dailyExporting = true);
    try {
      final included = rs.dailyRows.where((r) => r.isIncluded).toList()
        ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
      final path = await ReportExportService().exportDaily(
        report: rs.report,
        includedRows: included,
        repo: ref.read(reportsRepositoryProvider),
        roundingMode: _roundingMode,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم الحفظ: $path')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التصدير')),
      );
    } finally {
      if (mounted) setState(() => _dailyExporting = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Report header
// ---------------------------------------------------------------------------

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'تاريخ التوليد: ${_fmtDateTime(report.generationDatetime)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'النطاق: ${_fmtDate(report.rangeStart)} — ${_fmtDate(report.rangeEnd)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift tab
// ---------------------------------------------------------------------------

class _ShiftTab extends StatelessWidget {
  const _ShiftTab({
    required this.state,
    required this.roundingMode,
    required this.isExporting,
    required this.searchController,
    required this.onSearch,
    required this.onFilter,
    required this.onToggle,
    required this.onRowTap,
    required this.onExport,
  });

  final ReportState state;
  final String roundingMode;
  final bool isExporting;
  final TextEditingController searchController;
  final void Function(String) onSearch;
  final void Function(bool) onFilter;
  final void Function(int, bool) onToggle;
  final void Function(int) onRowTap;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleShiftRows;
    return Column(
      children: [
        _SummaryBar(children: [
          _SummaryCard(
              label: 'إجمالي الموظفين', value: '${state.totalShift}'),
          _SummaryCard(
              label: 'المحتسبون', value: '${state.includedShift}'),
          _SummaryCard(
              label: 'الساعات الإضافية',
              value: _fmt(state.totalShiftOvertimeMinutes, roundingMode)),
        ]),
        _FilterBar(
          showIncluded: state.shiftShowIncluded,
          searchController: searchController,
          onSearch: onSearch,
          onFilter: onFilter,
          isExporting: isExporting,
          onExport: onExport,
        ),
        const _TableHeader(
          columns: ['اسم الموظف', 'القسم', 'ساعات إضافية', 'محتسب'],
          flexes: [3, 2, 2, 1],
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyState(
                  message: state.shiftSearch.isEmpty
                      ? 'لا يوجد موظفون بنظام المناوبة'
                      : 'لا توجد نتائج مطابقة',
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _ShiftRow(
                    row: rows[i],
                    roundingMode: roundingMode,
                    onTap: () => onRowTap(rows[i].id),
                    onToggle: (v) => onToggle(rows[i].id, v),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daily tab
// ---------------------------------------------------------------------------

class _DailyTab extends StatelessWidget {
  const _DailyTab({
    required this.state,
    required this.roundingMode,
    required this.isExporting,
    required this.searchController,
    required this.onSearch,
    required this.onFilter,
    required this.onToggle,
    required this.onRowTap,
    required this.onExport,
  });

  final ReportState state;
  final String roundingMode;
  final bool isExporting;
  final TextEditingController searchController;
  final void Function(String) onSearch;
  final void Function(bool) onFilter;
  final void Function(int, bool) onToggle;
  final void Function(int) onRowTap;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleDailyRows;
    return Column(
      children: [
        _SummaryBar(children: [
          _SummaryCard(
              label: 'إجمالي الموظفين', value: '${state.totalDaily}'),
          _SummaryCard(
              label: 'المحتسبون', value: '${state.includedDaily}'),
          _SummaryCard(
              label: 'الساعات الإضافية',
              value: _fmt(state.totalDailyOvertimeMinutes, roundingMode)),
        ]),
        _FilterBar(
          showIncluded: state.dailyShowIncluded,
          searchController: searchController,
          onSearch: onSearch,
          onFilter: onFilter,
          isExporting: isExporting,
          onExport: onExport,
        ),
        const _TableHeader(
          columns: ['اسم الموظف', 'القسم', 'المجموع', 'محتسب'],
          flexes: [3, 2, 2, 1],
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyState(
                  message: state.dailySearch.isEmpty
                      ? 'لا يوجد موظفون بنظام الدوام الصباحي'
                      : 'لا توجد نتائج مطابقة',
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _DailyRow(
                    row: rows[i],
                    roundingMode: roundingMode,
                    onTap: () => onRowTap(rows[i].id),
                    onToggle: (v) => onToggle(rows[i].id, v),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Undetected tab
// ---------------------------------------------------------------------------

class _UndetectedTab extends StatelessWidget {
  const _UndetectedTab({
    required this.state,
    required this.searchController,
    required this.onSearch,
  });

  final ReportState state;
  final TextEditingController searchController;
  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleUndetectedRows;
    return Column(
      children: [
        _SummaryBar(children: [
          _SummaryCard(
              label: 'غير محدَّدون', value: '${state.totalUndetected}'),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'بحث باسم الموظف أو القسم',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: onSearch,
          ),
        ),
        const _TableHeader(
          columns: ['اسم الموظف', 'القسم', 'سبب عدم الكشف'],
          flexes: [3, 2, 3],
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyState(
                  message: state.undetectedSearch.isEmpty
                      ? 'تم كشف جميع الموظفين بنجاح'
                      : 'لا توجد نتائج مطابقة',
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _UndetectedRow(row: rows[i]),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: children
            .map((c) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                )))
            .toList(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.showIncluded,
    required this.searchController,
    required this.onSearch,
    required this.onFilter,
    required this.isExporting,
    required this.onExport,
  });

  final bool showIncluded;
  final TextEditingController searchController;
  final void Function(String) onSearch;
  final void Function(bool) onFilter;
  final bool isExporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          RadioGroup<bool>(
            groupValue: showIncluded,
            onChanged: (v) { if (v != null) onFilter(v); },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicWidth(
                  child: RadioListTile<bool>(
                    value: true,
                    title: const Text('محتسبون'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                IntrinsicWidth(
                  child: RadioListTile<bool>(
                    value: false,
                    title: const Text('مستثنون'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'بحث',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          isExporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('تصدير Excel'),
                ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.flexes});

  final List<String> columns;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                columns[i],
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Employee row widgets
// ---------------------------------------------------------------------------

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.row,
    required this.roundingMode,
    required this.onTap,
    required this.onToggle,
  });

  final ShiftEmployeeRow row;
  final String roundingMode;
  final VoidCallback onTap;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(row.employeeName)),
            Expanded(flex: 2, child: Text(row.department)),
            Expanded(
              flex: 2,
              child: Text(_fmt(row.overtimeMinutes, roundingMode)),
            ),
            Expanded(
              flex: 1,
              child: Switch(
                value: row.isIncluded,
                onChanged: onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.row,
    required this.roundingMode,
    required this.onTap,
    required this.onToggle,
  });

  final DailyEmployeeRow row;
  final String roundingMode;
  final VoidCallback onTap;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(row.employeeName)),
            Expanded(flex: 2, child: Text(row.department)),
            Expanded(
              flex: 2,
              child: Text(_fmt(row.totalOvertimeMinutes, roundingMode)),
            ),
            Expanded(
              flex: 1,
              child: Switch(
                value: row.isIncluded,
                onChanged: onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UndetectedRow extends StatelessWidget {
  const _UndetectedRow({required this.row});

  final UndetectedEmployeeRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(row.employeeName)),
          Expanded(flex: 2, child: Text(row.department)),
          Expanded(flex: 3, child: Text(row.failureReason)),
        ],
      ),
    );
  }
}
