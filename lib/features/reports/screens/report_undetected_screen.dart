import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/undetected_employee_row.dart';
import '../providers/reports_provider.dart';

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
  String? _deptFilter;   // null = all
  String? _reasonFilter; // null = all

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: state.whenOrNull(
              data: (rs) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Text('غير محدَّدون'),
                  const SizedBox(width: 8),
                  Text(
                    '(${rs.undetectedRows.length})',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ) ??
            const Text('غير محدَّدون'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('حدث خطأ أثناء التحميل: $e')),
        data: (rs) {
          final allRows = rs.undetectedRows;
          final rows = _filtered(allRows);

          final depts = ({...allRows.map((r) => r.department)}.toList()
                ..sort())
              .cast<String>();
          final reasons = ({...allRows.map((r) => r.failureReason)}.toList()
                ..sort())
              .cast<String>();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
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
                            child: Text(
                              _hasFilter
                                  ? 'لا توجد نتائج مطابقة'
                                  : 'تم كشف جميع الموظفين بنجاح',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (_, i) => _UndetectedRow(
                              row: rows[i],
                              onTap: () => context.push(
                                '/report/${widget.reportId}/detail/undetected/${rows[i].id}',
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline filter header — labels + controls in one block
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
    final labelStyle =
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column labels
          Row(
            children: [
              Expanded(flex: 3, child: Text('اسم الموظف', style: labelStyle)),
              Expanded(flex: 2, child: Text('القسم', style: labelStyle)),
              Expanded(flex: 3, child: Text('سبب عدم الكشف', style: labelStyle)),
            ],
          ),
          const SizedBox(height: 6),
          // Filter controls
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 16),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: onNameChanged,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterDropdown(
                    hint: 'الكل',
                    value: selectedDept,
                    items: depts,
                    onChanged: onDeptChanged,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _FilterDropdown(
                  hint: 'الكل',
                  value: selectedReason,
                  items: reasons,
                  onChanged: onReasonChanged,
                ),
              ),
            ],
          ),
        ],
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
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          underline: const SizedBox(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          hint: Text(hint,
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
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
// Row widget
// ---------------------------------------------------------------------------

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
