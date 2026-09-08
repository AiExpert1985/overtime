import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/unified_employee_row.dart';
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

String _typeLabel(EmployeeType type) => switch (type) {
      EmployeeType.shift => 'مناوبة',
      EmployeeType.daily => 'دوام صباحي',
      EmployeeType.undetected => 'غير محدد',
    };

MaterialColor _typeColor(EmployeeType type) => switch (type) {
      EmployeeType.shift => Colors.indigo,
      EmployeeType.daily => Colors.green,
      EmployeeType.undetected => Colors.orange,
    };

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
  late final TextEditingController _search;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ReportNotifier get _notifier =>
      ref.read(reportProvider(widget.reportId).notifier);

  // Undetected rows have no inclusion concept, and audit users are
  // read-only — both cases disable the toggle entirely.
  void Function(bool)? _onToggleFor(UnifiedEmployeeRow row, bool canEdit) {
    if (!canEdit || row.type == EmployeeType.undetected) return null;
    return row.type == EmployeeType.shift
        ? (v) => _notifier.toggleShiftIncluded(row.id, v)
        : (v) => _notifier.toggleDailyIncluded(row.id, v);
  }

  String get _roundingMode =>
      ref.read(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
      'quarter';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider(widget.reportId));
    final rs = state.whenOrNull(data: (v) => v);
    final theme = Theme.of(context);
    // Audit is read-only: no inclusion-toggle mutations.
    final canEdit = ref.watch(currentUserProvider) != UserRole.audit;

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
        toolbarHeight: 68,
        actions: [
          if (rs != null) ...[
            _exporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ أثناء التحميل',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$e',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              data: (rs) {
                final rows = rs.visibleRows;
                final depts = ({
                  ...rs.shiftRows.map((r) => r.department),
                  ...rs.dailyRows.map((r) => r.department),
                  ...rs.undetectedRows.map((r) => r.department),
                }.toList()..sort()).cast<String>();

                return Column(
                  children: [
                    _InlineFilterHeader(
                      searchController: _search,
                      depts: depts,
                      selectedDept: rs.deptFilter,
                      onSearch: (q) => _notifier.setSearch(q),
                      onDeptChanged: (v) => _notifier.setDeptFilter(v),
                      showShiftType: rs.showShiftType,
                      showDailyType: rs.showDailyType,
                      showUndetectedType: rs.showUndetectedType,
                      onShowShiftTypeChanged: (v) =>
                          _notifier.setShowShiftType(v),
                      onShowDailyTypeChanged: (v) =>
                          _notifier.setShowDailyType(v),
                      onShowUndetectedTypeChanged: (v) =>
                          _notifier.setShowUndetectedType(v),
                      hasOvertime: rs.hasOvertime,
                      noOvertime: rs.noOvertime,
                      showIncluded: rs.showIncluded,
                      showExcluded: rs.showExcluded,
                      onHasOvertimeChanged: (v) =>
                          _notifier.setHasOvertime(v),
                      onNoOvertimeChanged: (v) => _notifier.setNoOvertime(v),
                      onShowIncludedChanged: (v) =>
                          _notifier.setShowIncluded(v),
                      onShowExcludedChanged: (v) =>
                          _notifier.setShowExcluded(v),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? _EmptyState(
                              message: rs.shiftRows.isEmpty &&
                                      rs.dailyRows.isEmpty &&
                                      rs.undetectedRows.isEmpty
                                  ? 'لا يوجد موظفون في هذا التقرير'
                                  : 'لا توجد نتائج مطابقة للفلاتر المختارة',
                              icon: rs.shiftRows.isEmpty &&
                                      rs.dailyRows.isEmpty &&
                                      rs.undetectedRows.isEmpty
                                  ? Icons.people_outline_rounded
                                  : Icons.search_off_rounded,
                            )
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (_, i) => _UnifiedRow(
                                row: rows[i],
                                index: i,
                                roundingMode: _roundingMode,
                                onTap: () => context.push(
                                  '/report/${widget.reportId}/detail/'
                                  '${rows[i].type.name}/${rows[i].id}',
                                ),
                                onToggle: _onToggleFor(rows[i], canEdit),
                              ),
                            ),
                    ),

                    // Sticky bottom summary — occupies the slot the removed
                    // مناوبة/دوام صباحي tab selector used to sit in.
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 18, 0, 18),
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.67,
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  label: 'الموظفون المشمولون',
                                  value: '${rs.includedEmployees}',
                                  icon: Icons.how_to_reg_rounded,
                                  accentColor: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'إضافي العطل',
                                  value: _fmt(
                                    rs.includedOffOvertimeMinutes,
                                    _roundingMode,
                                  ),
                                  icon: Icons.weekend_rounded,
                                  accentColor: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'إضافي الدوام',
                                  value: _fmt(
                                    rs.includedRegularOvertimeMinutes,
                                    _roundingMode,
                                  ),
                                  icon: Icons.work_rounded,
                                  accentColor: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'إجمالي الوقت الإضافي',
                                  value: _fmt(
                                    rs.includedTotalOvertimeMinutes,
                                    _roundingMode,
                                  ),
                                  icon: Icons.verified_rounded,
                                  accentColor: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(ReportState rs) async {
    setState(() => _exporting = true);
    try {
      final includedShift = rs.shiftRows.where((r) => r.isIncluded).toList();
      final includedDaily = rs.dailyRows.where((r) => r.isIncluded).toList();
      final path = await ReportExportService().exportUnified(
        report: rs.report,
        includedShiftRows: includedShift,
        includedDailyRows: includedDaily,
        roundingMode: _roundingMode,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم الحفظ: $path')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء التصدير')));
    } finally {
      if (mounted) setState(() => _exporting = false);
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card — accent bar + icon one end, value+label other end
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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leading accent bar (right edge in RTL)
            Container(width: 5, color: accentColor),
            // Content: icon + label on leading side, value on trailing side
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leading side (right in RTL): icon + label text
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: accentColor, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Trailing side (left in RTL): value number only
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
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
// Inline filter header — visually distinct from table rows
// ---------------------------------------------------------------------------

class _InlineFilterHeader extends StatelessWidget {
  const _InlineFilterHeader({
    required this.searchController,
    required this.depts,
    required this.selectedDept,
    required this.onSearch,
    required this.onDeptChanged,
    required this.showShiftType,
    required this.showDailyType,
    required this.showUndetectedType,
    required this.onShowShiftTypeChanged,
    required this.onShowDailyTypeChanged,
    required this.onShowUndetectedTypeChanged,
    required this.hasOvertime,
    required this.noOvertime,
    required this.showIncluded,
    required this.showExcluded,
    required this.onHasOvertimeChanged,
    required this.onNoOvertimeChanged,
    required this.onShowIncludedChanged,
    required this.onShowExcludedChanged,
  });

  final TextEditingController searchController;
  final List<String> depts;
  final String? selectedDept;
  final void Function(String) onSearch;
  final void Function(String?) onDeptChanged;

  final bool showShiftType;
  final bool showDailyType;
  final bool showUndetectedType;
  final void Function(bool) onShowShiftTypeChanged;
  final void Function(bool) onShowDailyTypeChanged;
  final void Function(bool) onShowUndetectedTypeChanged;

  final bool hasOvertime;
  final bool noOvertime;
  final bool showIncluded;
  final bool showExcluded;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;
  final void Function(bool) onShowIncludedChanged;
  final void Function(bool) onShowExcludedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(flex: 1, child: SizedBox()),
          // Type filter — same paired-checkbox convention as the other
          // toggle pairs: all unchecked hides everything of that kind.
          Expanded(
            flex: 2,
            child: Center(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  _ToggleChip(
                    label: 'مناوبة',
                    selected: showShiftType,
                    onSelected: onShowShiftTypeChanged,
                  ),
                  _ToggleChip(
                    label: 'دوام صباحي',
                    selected: showDailyType,
                    onSelected: onShowDailyTypeChanged,
                  ),
                  _ToggleChip(
                    label: 'غير محدد',
                    selected: showUndetectedType,
                    onSelected: onShowUndetectedTypeChanged,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.75,
                child: _FilterTextField(
                  controller: searchController,
                  hint: 'اسم الموظف',
                  onChanged: onSearch,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.75,
                child: _FilterDropdown(
                  hint: 'القسم',
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
                    label: 'لديه وقت اضافي',
                    selected: hasOvertime,
                    onSelected: onHasOvertimeChanged,
                  ),
                  _ToggleChip(
                    label: 'بدون وقت اضافي',
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
    );
  }
}

// ---------------------------------------------------------------------------
// Filter widgets
// ---------------------------------------------------------------------------

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.controller,
    required this.onChanged,
    this.hint,
  });

  final TextEditingController controller;
  final void Function(String) onChanged;
  final String? hint;

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
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
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
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('كل الاقسام', style: const TextStyle(fontSize: 13)),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
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
// Unified employee row — renders shift, daily and undetected rows alike
// ---------------------------------------------------------------------------

class _UnifiedRow extends StatelessWidget {
  const _UnifiedRow({
    required this.row,
    required this.index,
    required this.roundingMode,
    required this.onTap,
    required this.onToggle,
  });

  final UnifiedEmployeeRow row;
  final int index;
  final String roundingMode;
  final VoidCallback onTap;
  // Null for undetected rows (no inclusion concept) and when editing is
  // disallowed (audit role).
  final void Function(bool)? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncluded = row.isIncluded;
    final hasOvertime = row.overtimeMinutes > 0;
    final isUndetected = row.type == EmployeeType.undetected;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: !isIncluded && !isUndetected
              ? Colors.grey.withValues(alpha: 0.06)
              : hasOvertime
              ? Colors.teal.withValues(alpha: 0.05)
              : null,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              width: 0.5,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Leading accent bar (right side in RTL = start edge)
              Container(
                width: 3,
                color: isIncluded
                    ? Colors.teal.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      // Row number badge
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isIncluded
                                  ? Colors.teal.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isIncluded
                                      ? Colors.teal.shade700
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Type badge — centered
                      Expanded(
                        flex: 2,
                        child: Center(child: _TypeBadge(type: row.type)),
                      ),
                      // Employee name — centered
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            row.employeeName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: !isIncluded && !isUndetected
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Department — centered
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            row.department,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Overtime — centered
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: _OvertimeCell(
                            row: row,
                            hasOvertime: hasOvertime,
                            roundingMode: roundingMode,
                          ),
                        ),
                      ),
                      // Selection — checkbox for shift/daily, failure reason
                      // for undetected (they have no inclusion concept).
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: isUndetected
                              ? _FailureReasonBadge(
                                  reason: row.undetected!.failureReason,
                                )
                              : Checkbox(
                                  value: row.isIncluded,
                                  onChanged: onToggle == null
                                      ? null
                                      : (v) => onToggle!(v ?? row.isIncluded),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row sub-widgets
// ---------------------------------------------------------------------------

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final EmployeeType type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _OvertimeCell extends StatelessWidget {
  const _OvertimeCell({
    required this.row,
    required this.hasOvertime,
    required this.roundingMode,
  });

  final UnifiedEmployeeRow row;
  final bool hasOvertime;
  final String roundingMode;

  @override
  Widget build(BuildContext context) {
    if (!hasOvertime) return const SizedBox.shrink();

    // Undetected rows never carry overtime — this branch is unreachable for
    // them since hasOvertime is always false, but kept exhaustive for shift
    // vs daily.
    if (row.type == EmployeeType.daily) {
      final daily = row.daily!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (daily.offOvertimeMinutes > 0)
            _LabeledOvertime(
              label: 'عطلة',
              value: _fmt(daily.offOvertimeMinutes, roundingMode),
              color: Colors.blue,
            ),
          if (daily.regularOvertimeMinutes > 0) ...[
            if (daily.offOvertimeMinutes > 0) const SizedBox(height: 3),
            _LabeledOvertime(
              label: 'دوام',
              value: _fmt(daily.regularOvertimeMinutes, roundingMode),
              color: Colors.amber,
            ),
          ],
          if (daily.offOvertimeMinutes > 0 &&
              daily.regularOvertimeMinutes > 0) ...[
            const SizedBox(height: 3),
            _LabeledOvertime(
              label: 'الكلي',
              value: _fmt(daily.totalOvertimeMinutes, roundingMode),
              color: Colors.green,
            ),
          ],
        ],
      );
    }

    // A shift employee's overtime is working-day overtime — same "دوام"
    // label and styling daily rows use for their regular-day figure, so the
    // column reads identically regardless of employee type.
    return _LabeledOvertime(
      label: 'دوام',
      value: _fmt(row.overtimeMinutes, roundingMode),
      color: Colors.amber,
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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

// Undetected employees have no inclusion checkbox — this slot shows the
// reason instead, truncated with a tooltip carrying the full text.
class _FailureReasonBadge extends StatelessWidget {
  const _FailureReasonBadge({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade800,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
