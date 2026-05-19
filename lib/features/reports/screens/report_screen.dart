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

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int _selectedTab = 0;
  late final TextEditingController _shiftSearch;
  late final TextEditingController _shiftDeptSearch;
  late final TextEditingController _dailySearch;
  late final TextEditingController _dailyDeptSearch;
  bool _shiftExporting = false;
  bool _dailyExporting = false;

  @override
  void initState() {
    super.initState();
    _shiftSearch = TextEditingController();
    _shiftDeptSearch = TextEditingController();
    _dailySearch = TextEditingController();
    _dailyDeptSearch = TextEditingController();
  }

  @override
  void dispose() {
    _shiftSearch.dispose();
    _shiftDeptSearch.dispose();
    _dailySearch.dispose();
    _dailyDeptSearch.dispose();
    super.dispose();
  }

  ReportNotifier get _notifier =>
      ref.read(reportProvider(widget.reportId).notifier);

  String get _roundingMode =>
      ref.read(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
      'quarter';

  void _showUndetectedDialog(ReportState rs) {
    showDialog(
      context: context,
      builder: (_) => _UndetectedDialog(
        rows: rs.undetectedRows,
        onRowTap: (id) {
          Navigator.of(context).pop();
          context.push('/report/${widget.reportId}/detail/undetected/$id');
        },
      ),
    );
  }

  bool get _isExporting =>
      _selectedTab == 0 ? _shiftExporting : _dailyExporting;

  void _doExport(ReportState rs) {
    if (_selectedTab == 0) {
      _doExportShift(rs);
    } else {
      _doExportDaily(rs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider(widget.reportId));
    final rs = state.whenOrNull(data: (v) => v);
    final undetectedCount = rs?.totalUndetected ?? 0;

    final appBarTitle = rs != null
        ? 'تقرير الوقت الاضافي للفترة من ${_fmtDate(rs.report.rangeStart)} الى ${_fmtDate(rs.report.rangeEnd)}'
        : 'التقرير';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          // Export button — leftmost in RTL (last in actions list)
          if (rs != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: _isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download_rounded),
                      tooltip: 'تصدير Excel',
                      onPressed: () => _doExport(rs),
                    ),
            ),
          // Undetected employees warning button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Badge(
              label: Text('$undetectedCount'),
              isLabelVisible: undetectedCount > 0,
              backgroundColor: Colors.orange.shade700,
              child: IconButton(
                icon: Icon(
                  Icons.warning_amber_rounded,
                  color: undetectedCount > 0
                      ? Colors.orange.shade700
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: 'الموظفون غير المحدَّدون',
                onPressed: rs != null ? () => _showUndetectedDialog(rs) : null,
              ),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('حدث خطأ أثناء التحميل: $e')),
        data: (rs) => Column(
          children: [
            // Segment buttons — larger and more dominant
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                segments: const [
                  ButtonSegment(value: 0, label: Text('مناوبة')),
                  ButtonSegment(value: 1, label: Text('صباحي')),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (s) =>
                    setState(() => _selectedTab = s.first),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _ShiftTab(
                    state: rs,
                    roundingMode: _roundingMode,
                    nameController: _shiftSearch,
                    deptController: _shiftDeptSearch,
                    onSearch: (q) => _notifier.setShiftSearch(q),
                    onDeptSearch: (q) => _notifier.setShiftDeptSearch(q),
                    onHasOvertimeChanged: (v) =>
                        _notifier.setShiftHasOvertime(v),
                    onNoOvertimeChanged: (v) =>
                        _notifier.setShiftNoOvertime(v),
                    onShowIncludedChanged: (v) =>
                        _notifier.setShiftShowIncluded(v),
                    onShowExcludedChanged: (v) =>
                        _notifier.setShiftShowExcluded(v),
                    onToggle: (id, v) => _notifier.toggleShiftIncluded(id, v),
                    onRowTap: (id) => context
                        .push('/report/${widget.reportId}/detail/shift/$id'),
                  ),
                  _DailyTab(
                    state: rs,
                    roundingMode: _roundingMode,
                    nameController: _dailySearch,
                    deptController: _dailyDeptSearch,
                    onSearch: (q) => _notifier.setDailySearch(q),
                    onDeptSearch: (q) => _notifier.setDailyDeptSearch(q),
                    onHasOvertimeChanged: (v) =>
                        _notifier.setDailyHasOvertime(v),
                    onNoOvertimeChanged: (v) =>
                        _notifier.setDailyNoOvertime(v),
                    onShowIncludedChanged: (v) =>
                        _notifier.setDailyShowIncluded(v),
                    onShowExcludedChanged: (v) =>
                        _notifier.setDailyShowExcluded(v),
                    onToggle: (id, v) => _notifier.toggleDailyIncluded(id, v),
                    onRowTap: (id) => context
                        .push('/report/${widget.reportId}/detail/daily/$id'),
                  ),
                ],
              ),
            ),
            _ReportFooter(report: rs.report),
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
// Report footer — generation date only
// ---------------------------------------------------------------------------

class _ReportFooter extends StatelessWidget {
  const _ReportFooter({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 1),
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'تاريخ التوليد: ${_fmtDateTime(report.generationDatetime)}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
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
    required this.nameController,
    required this.deptController,
    required this.onSearch,
    required this.onDeptSearch,
    required this.onHasOvertimeChanged,
    required this.onNoOvertimeChanged,
    required this.onShowIncludedChanged,
    required this.onShowExcludedChanged,
    required this.onToggle,
    required this.onRowTap,
  });

  final ReportState state;
  final String roundingMode;
  final TextEditingController nameController;
  final TextEditingController deptController;
  final void Function(String) onSearch;
  final void Function(String) onDeptSearch;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;
  final void Function(int, bool) onToggle;
  final void Function(int) onRowTap;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleShiftRows;
    return Column(
      children: [
        _SummaryBar(children: [
          _SummaryCard(
            label: 'إجمالي موظفي المناوبة',
            value: '${state.totalShift}',
          ),
          _SummaryCard(
            label: 'عدد الموظفين المشمولين',
            value: '${state.includedShift}',
          ),
          _SummaryCard(
            label: 'الوقت الاضافي الكلي للمناوبة',
            value: _fmt(state.totalShiftOvertimeAllMinutes, roundingMode),
          ),
          _SummaryCard(
            label: 'الوقت الاضافي المحتسب للمناوبة',
            value: _fmt(state.totalShiftOvertimeMinutes, roundingMode),
          ),
        ]),
        _InlineFilterHeader(
          overtimeLabel: 'ساعات إضافية',
          nameController: nameController,
          deptController: deptController,
          onNameSearch: onSearch,
          onDeptSearch: onDeptSearch,
          hasOvertime: state.shiftHasOvertime,
          noOvertime: state.shiftNoOvertime,
          showIncluded: state.shiftShowIncluded,
          showExcluded: state.shiftShowExcluded,
          onHasOvertimeChanged: onHasOvertimeChanged,
          onNoOvertimeChanged: onNoOvertimeChanged,
          onShowIncludedChanged: onShowIncludedChanged,
          onShowExcludedChanged: onShowExcludedChanged,
          isDaily: false,
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyState(
                  message: state.shiftRows.isEmpty
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
    required this.nameController,
    required this.deptController,
    required this.onSearch,
    required this.onDeptSearch,
    required this.onHasOvertimeChanged,
    required this.onNoOvertimeChanged,
    required this.onShowIncludedChanged,
    required this.onShowExcludedChanged,
    required this.onToggle,
    required this.onRowTap,
  });

  final ReportState state;
  final String roundingMode;
  final TextEditingController nameController;
  final TextEditingController deptController;
  final void Function(String) onSearch;
  final void Function(String) onDeptSearch;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;
  final void Function(int, bool) onToggle;
  final void Function(int) onRowTap;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleDailyRows;
    return Column(
      children: [
        _SummaryBar(children: [
          _SummaryCard(
            label: 'إجمالي موظفي الدوام الصباحي',
            value: '${state.totalDaily}',
          ),
          _SummaryCard(
            label: 'عدد الموظفين المشمولين',
            value: '${state.includedDaily}',
          ),
          _SummaryCard(
            label: 'الوقت الاضافي الكلي للدوام الصباحي',
            value: _fmt(state.totalDailyOvertimeAllMinutes, roundingMode),
          ),
          _SummaryCard(
            label: 'الوقت الاضافي المحتسب للدوام الصباحي',
            value: _fmt(state.totalDailyOvertimeMinutes, roundingMode),
          ),
        ]),
        _InlineFilterHeader(
          overtimeLabel: 'كلي',
          nameController: nameController,
          deptController: deptController,
          onNameSearch: onSearch,
          onDeptSearch: onDeptSearch,
          hasOvertime: state.dailyHasOvertime,
          noOvertime: state.dailyNoOvertime,
          showIncluded: state.dailyShowIncluded,
          showExcluded: state.dailyShowExcluded,
          onHasOvertimeChanged: onHasOvertimeChanged,
          onNoOvertimeChanged: onNoOvertimeChanged,
          onShowIncludedChanged: onShowIncludedChanged,
          onShowExcludedChanged: onShowExcludedChanged,
          isDaily: true,
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyState(
                  message: state.dailyRows.isEmpty
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
// Undetected dialog
// ---------------------------------------------------------------------------

class _UndetectedDialog extends StatefulWidget {
  const _UndetectedDialog({
    required this.rows,
    required this.onRowTap,
  });

  final List<UndetectedEmployeeRow> rows;
  final void Function(int) onRowTap;

  @override
  State<_UndetectedDialog> createState() => _UndetectedDialogState();
}

class _UndetectedDialogState extends State<_UndetectedDialog> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<UndetectedEmployeeRow> get _filtered {
    var list = List<UndetectedEmployeeRow>.from(widget.rows);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((r) =>
              r.employeeName.toLowerCase().contains(q) ||
              r.department.toLowerCase().contains(q))
          .toList();
    }
    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _filtered;

    return Dialog(
      child: SizedBox(
        width: 600,
        height: 450,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'غير محدَّدون',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${widget.rows.length})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'بحث باسم الموظف',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            const _TableHeader(
              columns: ['اسم الموظف', 'القسم', 'سبب عدم الكشف'],
              flexes: [3, 2, 3],
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'تم كشف جميع الموظفين بنجاح'
                            : 'لا توجد نتائج مطابقة',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _UndetectedRow(
                        row: rows[i],
                        onTap: () => widget.onRowTap(rows[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
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
            .map((c) => Expanded(
                    child: Padding(
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

// Kept for the undetected dialog.
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

class _InlineFilterHeader extends StatelessWidget {
  const _InlineFilterHeader({
    required this.overtimeLabel,
    required this.nameController,
    required this.deptController,
    required this.onNameSearch,
    required this.onDeptSearch,
    required this.hasOvertime,
    required this.noOvertime,
    required this.showIncluded,
    required this.showExcluded,
    required this.onHasOvertimeChanged,
    required this.onNoOvertimeChanged,
    required this.onShowIncludedChanged,
    required this.onShowExcludedChanged,
    required this.isDaily,
  });

  final String overtimeLabel;
  final TextEditingController nameController;
  final TextEditingController deptController;
  final void Function(String) onNameSearch;
  final void Function(String) onDeptSearch;
  final bool hasOvertime;
  final bool noOvertime;
  final bool showIncluded;
  final bool showExcluded;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;
  // When true, renders 3 overtime sub-columns (دوام / عطلة / كلي)
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);

    if (isDaily) {
      return _buildDailyHeader(context, labelStyle);
    }
    return _buildShiftHeader(context, labelStyle);
  }

  Widget _buildShiftHeader(BuildContext context, TextStyle? labelStyle) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('اسم الموظف', style: labelStyle)),
              Expanded(flex: 2, child: Text('القسم', style: labelStyle)),
              Expanded(flex: 2, child: Text(overtimeLabel, style: labelStyle)),
              Expanded(
                flex: 2,
                child: Text('المشمولون بالوقت الإضافي', style: labelStyle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterTextField(
                    controller: nameController,
                    onChanged: onNameSearch,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterTextField(
                    controller: deptController,
                    onChanged: onDeptSearch,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CheckRow(
                      label: 'لديه اضافي',
                      value: hasOvertime,
                      onChanged: onHasOvertimeChanged,
                    ),
                    _CheckRow(
                      label: 'بدون اضافي',
                      value: noOvertime,
                      onChanged: onNoOvertimeChanged,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CheckRow(
                      label: 'مشمول',
                      value: showIncluded,
                      onChanged: onShowIncludedChanged,
                    ),
                    _CheckRow(
                      label: 'غير مشمول',
                      value: showExcluded,
                      onChanged: onShowExcludedChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHeader(BuildContext context, TextStyle? labelStyle) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('اسم الموظف', style: labelStyle)),
              Expanded(flex: 2, child: Text('القسم', style: labelStyle)),
              Expanded(flex: 2, child: Text('دوام', style: labelStyle)),
              Expanded(flex: 2, child: Text('عطلة', style: labelStyle)),
              Expanded(flex: 2, child: Text('كلي', style: labelStyle)),
              Expanded(
                flex: 2,
                child: Text('المشمولون بالوقت الإضافي', style: labelStyle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterTextField(
                    controller: nameController,
                    onChanged: onNameSearch,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterTextField(
                    controller: deptController,
                    onChanged: onDeptSearch,
                  ),
                ),
              ),
              // دوام and عطلة columns have no filter controls — spacers only
              const Expanded(flex: 2, child: SizedBox()),
              const Expanded(flex: 2, child: SizedBox()),
              // كلي — overtime filter checkboxes operate on total
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CheckRow(
                      label: 'لديه اضافي',
                      value: hasOvertime,
                      onChanged: onHasOvertimeChanged,
                    ),
                    _CheckRow(
                      label: 'بدون اضافي',
                      value: noOvertime,
                      onChanged: onNoOvertimeChanged,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CheckRow(
                      label: 'مشمول',
                      value: showIncluded,
                      onChanged: onShowIncludedChanged,
                    ),
                    _CheckRow(
                      label: 'غير مشمول',
                      value: showExcluded,
                      onChanged: onShowExcludedChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 16),
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? value),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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
    final bg = !row.isIncluded
        ? Colors.grey.shade100
        : row.overtimeMinutes > 0
            ? Colors.amber.shade100
            : null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
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
              flex: 2,
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
    final bg = !row.isIncluded
        ? Colors.grey.shade100
        : row.totalOvertimeMinutes > 0
            ? Colors.amber.shade100
            : null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
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
              child: Text(_fmt(row.regularOvertimeMinutes, roundingMode)),
            ),
            Expanded(
              flex: 2,
              child: Text(_fmt(row.offOvertimeMinutes, roundingMode)),
            ),
            Expanded(
              flex: 2,
              child: Text(_fmt(row.totalOvertimeMinutes, roundingMode)),
            ),
            Expanded(
              flex: 2,
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
  const _UndetectedRow({required this.row, required this.onTap});

  final UndetectedEmployeeRow row;
  final VoidCallback onTap;

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
            Expanded(flex: 3, child: Text(row.failureReason)),
          ],
        ),
      ),
    );
  }
}
