import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/undetected_employee_row.dart';
import '../providers/reports_provider.dart';
import '../services/report_export_service.dart';

class ReportUndetectedScreen extends ConsumerStatefulWidget {
  const ReportUndetectedScreen({super.key, required this.reportId});

  final int reportId;

  @override
  ConsumerState<ReportUndetectedScreen> createState() =>
      _ReportUndetectedScreenState();
}

class _ReportUndetectedScreenState
    extends ConsumerState<ReportUndetectedScreen> {
  final _nameCtrl = TextEditingController();
  String _nameQuery = '';
  String? _deptFilter;
  String? _reasonFilter;
  bool _exporting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _doExport(ReportState rs) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await ReportExportService().exportUndetectedList(
        report: rs.report,
        rows: rs.undetectedRows,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تم الحفظ: $path')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء التصدير')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<UndetectedEmployeeRow> _filtered(List<UndetectedEmployeeRow> rows) {
    var list = List<UndetectedEmployeeRow>.from(rows);
    if (_nameQuery.isNotEmpty) {
      final q = _nameQuery.toLowerCase();
      list = list.where((r) => r.employeeName.toLowerCase().contains(q)).toList();
    }
    if (_deptFilter != null) {
      list = list.where((r) => r.department == _deptFilter).toList();
    }
    if (_reasonFilter != null) {
      list = list.where((r) => r.failureReason == _reasonFilter).toList();
    }
    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }

  bool get _hasFilter =>
      _nameQuery.isNotEmpty || _deptFilter != null || _reasonFilter != null;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider(widget.reportId));
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'الموظفون غير محدَّدون',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Builder(builder: (context) {
            final rs = ref
                .watch(reportProvider(widget.reportId))
                .whenOrNull(data: (v) => v);
            if (rs == null) return const SizedBox.shrink();
            return _exporting
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
                  );
          }),
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
                  Colors.orange.withValues(alpha: 0.04),
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
                      'جارٍ تحميل البيانات...',
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
                    Text('حدث خطأ أثناء التحميل',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 4),
                    Text('$e',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              data: (rs) {
                final allRows = rs.undetectedRows;
                final rows = _filtered(allRows);

                final depts = ({...allRows.map((r) => r.department)}.toList()
                      ..sort())
                    .cast<String>();
                final reasons =
                    ({...allRows.map((r) => r.failureReason)}.toList()..sort())
                        .cast<String>();

                return Column(
                  children: [
                    // Summary cards
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.67,
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  label: 'إجمالي غير المحدَّدين',
                                  value: '${allRows.length}',
                                  icon: Icons.warning_amber_rounded,
                                  accentColor: Colors.orange,
                                ),
                              ),
                              if (_hasFilter) ...[
                                const SizedBox(width: 22),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'نتائج التصفية',
                                    value: '${rows.length}',
                                    icon: Icons.filter_list_rounded,
                                    accentColor: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    _InlineFilterHeader(
                      nameCtrl: _nameCtrl,
                      depts: depts,
                      reasons: reasons,
                      selectedDept: _deptFilter,
                      selectedReason: _reasonFilter,
                      onNameChanged: (q) => setState(() => _nameQuery = q),
                      onDeptChanged: (v) => setState(() => _deptFilter = v),
                      onReasonChanged: (v) => setState(() => _reasonFilter = v),
                    ),

                    Expanded(
                      child: rows.isEmpty
                          ? Center(
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
                                      _hasFilter
                                          ? Icons.search_off_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 48,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _hasFilter
                                        ? 'لا توجد نتائج مطابقة'
                                        : 'تم كشف جميع الموظفين بنجاح',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                                  .animate()
                                  .fade()
                                  .scale(begin: const Offset(0.9, 0.9)),
                            )
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (_, i) => _UndetectedRow(
                                row: rows[i],
                                index: i,
                                onTap: () => context.push(
                                  '/report/${widget.reportId}/detail/undetected/${rows[i].id}',
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
}

// ---------------------------------------------------------------------------
// Inline filter header — styled to match report_screen
// ---------------------------------------------------------------------------

class _InlineFilterHeader extends StatelessWidget {
  const _InlineFilterHeader({
    required this.nameCtrl,
    required this.depts,
    required this.reasons,
    required this.selectedDept,
    required this.selectedReason,
    required this.onNameChanged,
    required this.onDeptChanged,
    required this.onReasonChanged,
  });

  final TextEditingController nameCtrl;
  final List<String> depts;
  final List<String> reasons;
  final String? selectedDept;
  final String? selectedReason;
  final void Function(String) onNameChanged;
  final void Function(String?) onDeptChanged;
  final void Function(String?) onReasonChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
      letterSpacing: 0.3,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outlineVariant, width: 0.5),
          bottom: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column label row
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Center(
                    child: Text('#',
                        style: labelStyle, textAlign: TextAlign.center)),
              ),
              Expanded(
                flex: 3,
                child: Center(
                    child: Text('اسم الموظف',
                        style: labelStyle, textAlign: TextAlign.center)),
              ),
              Expanded(
                flex: 2,
                child: Center(
                    child: Text('القسم',
                        style: labelStyle, textAlign: TextAlign.center)),
              ),
              Expanded(
                flex: 3,
                child: Center(
                    child: Text('سبب عدم الكشف',
                        style: labelStyle, textAlign: TextAlign.center)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filter controls row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Spacer for # column
              const Expanded(flex: 1, child: SizedBox()),
              // Name search
              Expanded(
                flex: 3,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.67,
                    child: _FilterTextField(
                      controller: nameCtrl,
                      onChanged: onNameChanged,
                    ),
                  ),
                ),
              ),
              // Dept dropdown
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
              // Reason dropdown
              Expanded(
                flex: 3,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.85,
                    child: _FilterDropdown(
                      hint: 'الكل',
                      value: selectedReason,
                      items: reasons,
                      onChanged: onReasonChanged,
                    ),
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
// Filter widgets — identical style to report_screen
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
          prefixIcon: Icon(Icons.search_rounded,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
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
          style:
              TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
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

// ---------------------------------------------------------------------------
// Row widget — styled to match report_screen rows
// ---------------------------------------------------------------------------

class _UndetectedRow extends StatelessWidget {
  const _UndetectedRow({
    required this.row,
    required this.index,
    required this.onTap,
  });

  final UndetectedEmployeeRow row;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
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
              // Leading orange accent bar
              Container(
                width: 3,
                color: Colors.orange.withValues(alpha: 0.6),
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
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
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Employee name
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            row.employeeName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Department
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
                      // Failure reason badge
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      Colors.orange.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              row.failureReason,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
// Summary card — identical to report_screen
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
  final MaterialColor accentColor;

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
            Container(width: 5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
// AppBar action button — icon + label stacked (matches report_screen style)
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
