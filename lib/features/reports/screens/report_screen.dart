import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../settings/providers/settings_provider.dart';
import '../domain/daily_employee_row.dart';
import '../domain/shift_employee_row.dart';
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
  late final TextEditingController _dailySearch;
  bool _shiftExporting = false;
  bool _dailyExporting = false;

  @override
  void initState() {
    super.initState();
    _shiftSearch = TextEditingController();
    _dailySearch = TextEditingController();
  }

  @override
  void dispose() {
    _shiftSearch.dispose();
    _dailySearch.dispose();
    super.dispose();
  }

  ReportNotifier get _notifier =>
      ref.read(reportProvider(widget.reportId).notifier);

  String get _roundingMode =>
      ref.read(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
      'quarter';

  void _showUndetected() {
    context.push('/report/${widget.reportId}/undetected');
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
    final theme = Theme.of(context);

    final appBarTitle = rs != null
        ? 'تقرير ${_fmtDate(rs.report.rangeStart)} — ${_fmtDate(rs.report.rangeEnd)}'
        : 'التقرير';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (rs != null) ...[
            _isExporting
                ? const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _AppBarAction(
                    icon: Icons.download_rounded,
                    label: 'تصدير',
                    onTap: () => _doExport(rs),
                  ),
          ],
          _AppBarAction(
            icon: Icons.warning_amber_rounded,
            label: 'غير محددين',
            iconColor:
                undetectedCount > 0 ? Colors.orange.shade700 : null,
            badge: undetectedCount > 0 ? '$undetectedCount' : null,
            badgeColor: Colors.orange.shade700,
            onTap: rs != null ? _showUndetected : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),

          SafeArea(
            child: state.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'جارٍ تحميل التقرير...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ أثناء التحميل',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$e',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              data: (rs) => Column(
                children: [
                  // Tab selector
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'مناوبة',
                            icon: Icons.swap_horiz_rounded,
                            selected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TabButton(
                            label: 'دوام صباحي',
                            icon: Icons.wb_sunny_rounded,
                            selected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                        ),
                      ],
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
                          onSearch: (q) => _notifier.setShiftSearch(q),
                          onDeptChanged: (v) =>
                              _notifier.setShiftDeptFilter(v),
                          onHasOvertimeChanged: (v) =>
                              _notifier.setShiftHasOvertime(v),
                          onNoOvertimeChanged: (v) =>
                              _notifier.setShiftNoOvertime(v),
                          onShowIncludedChanged: (v) =>
                              _notifier.setShiftShowIncluded(v),
                          onShowExcludedChanged: (v) =>
                              _notifier.setShiftShowExcluded(v),
                          onToggle: (id, v) =>
                              _notifier.toggleShiftIncluded(id, v),
                          onRowTap: (id) => context.push(
                              '/report/${widget.reportId}/detail/shift/$id'),
                        ),
                        _DailyTab(
                          state: rs,
                          roundingMode: _roundingMode,
                          nameController: _dailySearch,
                          onSearch: (q) => _notifier.setDailySearch(q),
                          onDeptChanged: (v) =>
                              _notifier.setDailyDeptFilter(v),
                          onHasOvertimeChanged: (v) =>
                              _notifier.setDailyHasOvertime(v),
                          onNoOvertimeChanged: (v) =>
                              _notifier.setDailyNoOvertime(v),
                          onShowIncludedChanged: (v) =>
                              _notifier.setDailyShowIncluded(v),
                          onShowExcludedChanged: (v) =>
                              _notifier.setDailyShowExcluded(v),
                          onToggle: (id, v) =>
                              _notifier.toggleDailyIncluded(id, v),
                          onRowTap: (id) => context.push(
                              '/report/${widget.reportId}/detail/daily/$id'),
                        ),
                      ],
                    ),
                  ),

                  // Bottom summary cards — replaces generation date footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: _SummaryCard(
                              label: 'الموظفون المشمولون',
                              value:
                                  '${_selectedTab == 0 ? rs.includedShift : rs.includedDaily}',
                              icon: Icons.how_to_reg_rounded,
                              accentColor: Colors.teal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: _SummaryCard(
                              label: 'الوقت الإضافي المحتسب',
                              value: _fmt(
                                _selectedTab == 0
                                    ? rs.totalShiftOvertimeMinutes
                                    : rs.totalDailyOvertimeMinutes,
                                _roundingMode,
                              ),
                              icon: Icons.verified_rounded,
                              accentColor: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
// AppBar action button — icon + label stacked
// ---------------------------------------------------------------------------

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.label,
    this.iconColor,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.onSurfaceVariant;

    Widget iconWidget = Icon(icon, size: 22, color: color);
    if (badge != null) {
      iconWidget = Badge(
        label: Text(badge!),
        backgroundColor: badgeColor,
        child: iconWidget,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab button — large rectangle, clear selected state
// ---------------------------------------------------------------------------

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.surface;
    final fgColor = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: selected
            ? [
                BoxShadow(
                  color:
                      theme.colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: fgColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card — centered content, accent bar on start edge
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leading accent bar (right = RTL start)
            Container(width: 5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
// Shift tab
// ---------------------------------------------------------------------------

class _ShiftTab extends StatelessWidget {
  const _ShiftTab({
    required this.state,
    required this.roundingMode,
    required this.nameController,
    required this.onSearch,
    required this.onDeptChanged,
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
  final void Function(String) onSearch;
  final void Function(String?) onDeptChanged;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;
  final void Function(int, bool) onToggle;
  final void Function(int) onRowTap;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleShiftRows;
    final depts = ({...state.shiftRows.map((r) => r.department)}.toList()
          ..sort())
        .cast<String>();

    return Column(
      children: [
        _InlineFilterHeader(
          overtimeLabel: 'ساعات إضافية',
          nameController: nameController,
          depts: depts,
          selectedDept: state.shiftDeptFilter,
          onNameSearch: onSearch,
          onDeptChanged: onDeptChanged,
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
                      : 'لا توجد نتائج مطابقة للفلاتر المختارة',
                  icon: state.shiftRows.isEmpty
                      ? Icons.people_outline_rounded
                      : Icons.search_off_rounded,
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
    required this.onSearch,
    required this.onDeptChanged,
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
  final void Function(String) onSearch;
  final void Function(String?) onDeptChanged;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;
  final void Function(int, bool) onToggle;
  final void Function(int) onRowTap;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleDailyRows;
    final depts = ({...state.dailyRows.map((r) => r.department)}.toList()
          ..sort())
        .cast<String>();

    return Column(
      children: [
        _InlineFilterHeader(
          overtimeLabel: 'كلي',
          nameController: nameController,
          depts: depts,
          selectedDept: state.dailyDeptFilter,
          onNameSearch: onSearch,
          onDeptChanged: onDeptChanged,
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
                      : 'لا توجد نتائج مطابقة للفلاتر المختارة',
                  icon: state.dailyRows.isEmpty
                      ? Icons.wb_sunny_outlined
                      : Icons.search_off_rounded,
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
// Inline filter header
// ---------------------------------------------------------------------------

class _InlineFilterHeader extends StatelessWidget {
  const _InlineFilterHeader({
    required this.overtimeLabel,
    required this.nameController,
    required this.depts,
    required this.selectedDept,
    required this.onNameSearch,
    required this.onDeptChanged,
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
  final List<String> depts;
  final String? selectedDept;
  final void Function(String) onNameSearch;
  final void Function(String?) onDeptChanged;
  final bool hasOvertime;
  final bool noOvertime;
  final bool showIncluded;
  final bool showExcluded;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.2,
    );
    final overtimeColumnLabel =
        isDaily ? 'الساعات الإضافية' : overtimeLabel;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outlineVariant, width: 0.5),
          bottom: BorderSide(
              color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Centered column labels
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: Text('اسم الموظف',
                      style: labelStyle,
                      textAlign: TextAlign.center),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text('القسم',
                      style: labelStyle,
                      textAlign: TextAlign.center),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(overtimeColumnLabel,
                      style: labelStyle,
                      textAlign: TextAlign.center),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text('المشمولون',
                      style: labelStyle,
                      textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Centered filter controls
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Name search — 2/3 of column width, centered
              Expanded(
                flex: 3,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.67,
                    child: _FilterTextField(
                      controller: nameController,
                      onChanged: onNameSearch,
                    ),
                  ),
                ),
              ),
              // Dept dropdown — 2/3 of column width, centered
              Expanded(
                flex: 2,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.67,
                    child: _FilterDropdown(
                      hint: 'الكل',
                      value: selectedDept,
                      items: depts,
                      onChanged: onDeptChanged,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _ToggleChip(
                        label: 'لديه اضافي',
                        selected: hasOvertime,
                        onSelected: onHasOvertimeChanged,
                      ),
                      _ToggleChip(
                        label: 'بدون اضافي',
                        selected: noOvertime,
                        onSelected: onNoOvertimeChanged,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _ToggleChip(
                        label: 'مشمول',
                        selected: showIncluded,
                        onSelected: onShowIncludedChanged,
                      ),
                      _ToggleChip(
                        label: 'غير مشمول',
                        selected: showExcluded,
                        onSelected: onShowExcludedChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter widgets
// ---------------------------------------------------------------------------

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          underline: const SizedBox(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          style: TextStyle(
              fontSize: 13, color: theme.colorScheme.onSurface),
          hint: Text(hint,
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant)),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint, style: const TextStyle(fontSize: 13)),
            ),
            ...items.map(
              (v) => DropdownMenuItem<String>(
                value: v,
                child: Text(v, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer
                  .withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
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
    final theme = Theme.of(context);
    final isIncluded = row.isIncluded;
    final hasOvertime = row.overtimeMinutes > 0;

    // Clear three-state background:
    //   included + overtime  → warm amber tint
    //   included, no OT      → soft primary/teal tint
    //   excluded             → muted grey
    final Color bgColor = !isIncluded
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
        : hasOvertime
            ? Colors.amber.withValues(alpha: 0.18)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.22);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant
                  .withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row.employeeName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: !isIncluded
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.department,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: hasOvertime
                  ? _OvertimeBadge(
                      value: _fmt(row.overtimeMinutes, roundingMode),
                      color: Colors.amber,
                    )
                  : const SizedBox.shrink(),
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
    final theme = Theme.of(context);
    final isIncluded = row.isIncluded;
    final hasOvertime = row.totalOvertimeMinutes > 0;

    final Color bgColor = !isIncluded
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
        : hasOvertime
            ? Colors.amber.withValues(alpha: 0.18)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.22);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant
                  .withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row.employeeName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: !isIncluded
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.department,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: !hasOvertime
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (row.offOvertimeMinutes > 0)
                          _LabeledOvertime(
                            label: 'عطلة',
                            value: _fmt(
                                row.offOvertimeMinutes, roundingMode),
                            color: Colors.blue,
                          ),
                        if (row.regularOvertimeMinutes > 0) ...[
                          if (row.offOvertimeMinutes > 0)
                            const SizedBox(height: 3),
                          _LabeledOvertime(
                            label: 'دوام',
                            value: _fmt(row.regularOvertimeMinutes,
                                roundingMode),
                            color: Colors.amber,
                          ),
                        ],
                        if (row.offOvertimeMinutes > 0 &&
                            row.regularOvertimeMinutes > 0) ...[
                          const SizedBox(height: 3),
                          _LabeledOvertime(
                            label: 'الكلي',
                            value: _fmt(
                                row.totalOvertimeMinutes, roundingMode),
                            color: Colors.green,
                          ),
                        ],
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Row sub-widgets
// ---------------------------------------------------------------------------

class _OvertimeBadge extends StatelessWidget {
  const _OvertimeBadge({required this.value, required this.color});

  final String value;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _LabeledOvertime extends StatelessWidget {
  const _LabeledOvertime({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color.shade800,
          ),
        ),
      ],
    );
  }
}
