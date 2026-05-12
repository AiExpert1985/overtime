import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/domain/employee.dart';
import '../../../reference_data/domain/employee_record.dart';
import '../../../reference_data/presentation/providers/reference_data_providers.dart';
import '../providers/report_generation_providers.dart';
import '../providers/report_generation_screen_providers.dart';
import '../providers/report_providers.dart';

class ReportGenerationScreen extends ConsumerWidget {
  const ReportGenerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportGenerationScreenProvider);
    final screenNotifier =
        ref.read(reportGenerationScreenProvider.notifier);
    final genState = ref.watch(generationProvider);
    final isLoading = genState is GenerationLoading;

    ref.listen<ReportGenerationScreenState>(reportGenerationScreenProvider,
        (prev, next) {
      if (next.unexpectedError != null &&
          next.unexpectedError != prev?.unexpectedError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.unexpectedError!),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        screenNotifier.clearError();
      }
    });

    ref.listen<GenerationState>(generationProvider, (prev, next) {
      switch (next) {
        case GenerationUnmatchedReview(:final unmatchedNames):
          _showUnmatchedDialog(context, ref, unmatchedNames);
        case GenerationSuccess(:final reportId):
          screenNotifier.saveSelectionToDb();
          ref.read(reportsVersionProvider.notifier).increment();
          ref.read(generationProvider.notifier).reset();
          context.goNamed('report',
              pathParameters: {'reportId': reportId.toString()});
        case GenerationError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
          ref.read(generationProvider.notifier).reset();
        default:
          break;
      }
    });

    return AbsorbPointer(
      absorbing: isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('توليد تقرير')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AttendanceFileCard(
                    state: state,
                    notifier: screenNotifier,
                  ),
                  const SizedBox(height: 24),
                  _DateRangeSection(state: state, notifier: screenNotifier),
                  const SizedBox(height: 24),
                  _EmployeeSelectionCard(
                    state: state,
                    notifier: screenNotifier,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: (state.canGenerate && !isLoading)
                        ? () => _generate(ref, state)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'توليد التقرير',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _generate(WidgetRef ref, ReportGenerationScreenState state) {
    final employees = state.selectedEmployees
        .map((e) => Employee(
              name: e.name,
              employmentType: e.employmentType,
              department: e.department,
            ))
        .toList();

    ref.read(generationProvider.notifier).generate(
          attendance: state.attendanceData,
          employees: employees,
          startDate: state.startDate!,
          endDate: state.endDate!,
        );
  }

  void _showUnmatchedDialog(
      BuildContext context, WidgetRef ref, List<String> names) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UnmatchedDialog(names: names, ref: ref),
    );
  }
}

// ── Unmatched Dialog ──────────────────────────────────────────────────────────

class _UnmatchedDialog extends ConsumerStatefulWidget {
  final List<String> names;
  final WidgetRef ref;

  const _UnmatchedDialog({required this.names, required this.ref});

  @override
  ConsumerState<_UnmatchedDialog> createState() => _UnmatchedDialogState();
}

class _UnmatchedDialogState extends ConsumerState<_UnmatchedDialog> {
  bool _exporting = false;
  String? _exportMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('موظفون غير موجودون في ملف الحضور'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لم يتم العثور على سجلات حضور للموظفين التاليين:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.names.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• ${widget.names[i]}',
                      style: theme.textTheme.bodySmall),
                ),
              ),
            ),
            if (_exportMessage != null) ...[
              const SizedBox(height: 8),
              Text(_exportMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting
              ? null
              : () async {
                  setState(() => _exporting = true);
                  final path = await ref
                      .read(generationProvider.notifier)
                      .exportUnmatchedNames(widget.names);
                  if (mounted) {
                    setState(() {
                      _exporting = false;
                      _exportMessage =
                          path != null ? 'تم التصدير: $path' : 'تعذّر التصدير';
                    });
                  }
                },
          child: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تصدير الأسماء'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(generationProvider.notifier).abort();
          },
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(generationProvider.notifier).continueWithUnmatched();
          },
          child: const Text('متابعة'),
        ),
      ],
    );
  }
}

// ── Attendance File Card ──────────────────────────────────────────────────────

class _AttendanceFileCard extends StatelessWidget {
  final ReportGenerationScreenState state;
  final ReportGenerationScreenNotifier notifier;

  const _AttendanceFileCard(
      {required this.state, required this.notifier});

  bool get _isEmpty => state.attendanceViews.isEmpty;
  bool get _allValid =>
      state.attendanceViews.isNotEmpty &&
      state.attendanceViews.every((e) => e.isValid);
  int get _invalidCount =>
      state.attendanceViews.where((e) => !e.isValid).length;

  Color? _cardColor(ThemeData theme) {
    if (_isEmpty) return null;
    if (_allValid) return Colors.green.shade50;
    return theme.colorScheme.errorContainer.withValues(alpha: 0.25);
  }

  String get _statusLabel {
    final count = state.attendanceViews.length;
    final countLabel = count == 1 ? 'ملف واحد' : '$count ملفات';
    if (_allValid) return '$countLabel • صالحة';
    if (_invalidCount == count) return '$countLabel • غير صالحة';
    return '$countLabel • $_invalidCount غير صالح';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      color: _cardColor(theme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'ملف الحضور',
                      style: _isEmpty
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            )
                          : theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'معلومات',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _showInfo(context),
                ),
              ],
            ),
            if (!_isEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showFileList(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        _allValid
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 15,
                        color: _allValid
                            ? Colors.green.shade700
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _statusLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _allValid
                                ? Colors.green.shade700
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: notifier.addAttendanceFiles,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(
                _isEmpty ? 'اختر ملفات' : 'إضافة ملفات',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ملف الحضور'),
        content: const Text(
          'ملف Excel يحتوي على عمودين: اسم الموظف، التاريخ والوقت. يمكن تقديم أكثر من ملف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showFileList(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AttendanceFileListDialog(notifier: notifier),
    );
  }
}

// ── Attendance File List Dialog ───────────────────────────────────────────────

class _AttendanceFileListDialog extends ConsumerWidget {
  final ReportGenerationScreenNotifier notifier;

  const _AttendanceFileListDialog({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportGenerationScreenProvider);
    final entries = state.attendanceViews;

    if (entries.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('ملف الحضور'),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 460,
        child: entries.isEmpty
            ? const SizedBox(height: 48)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('اسم الملف',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                        ),
                        Text('الحالة',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const Divider(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 20, endIndent: 20),
                      itemBuilder: (ctx, i) => _FileRow(
                        entry: entries[i],
                        onRemove: () => notifier.removeAttendanceFile(i),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

// ── File Row ──────────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  final FileEntryView entry;
  final VoidCallback onRemove;

  const _FileRow({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: entry.isValid
                      ? Colors.green.shade50
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.isValid
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 13,
                      color: entry.isValid
                          ? Colors.green.shade700
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      entry.isValid ? 'صالح' : 'غير صالح',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: entry.isValid
                            ? Colors.green.shade700
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.red.shade400,
                tooltip: 'حذف',
                padding: const EdgeInsets.all(4),
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            ],
          ),
          if (entry.errorMessage != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(
                entry.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Date Range Section ────────────────────────────────────────────────────────

class _DateRangeSection extends StatelessWidget {
  final ReportGenerationScreenState state;
  final ReportGenerationScreenNotifier notifier;

  const _DateRangeSection({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.dateRangeError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _DatePickerButton(
                label: 'من',
                date: state.startDate,
                onPick: notifier.setStartDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DatePickerButton(
                label: 'إلى',
                date: state.endDate,
                onPick: notifier.setEndDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onPick,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText =
        date != null ? DateFormat('yyyy/MM/dd').format(date!) : 'اختر تاريخاً';

    return OutlinedButton(
      onPressed: () => _pick(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              dateText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: date == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onPick(picked);
  }
}

// ── Employee Selection Card ───────────────────────────────────────────────────

class _EmployeeSelectionCard extends StatelessWidget {
  final ReportGenerationScreenState state;
  final ReportGenerationScreenNotifier notifier;

  const _EmployeeSelectionCard(
      {required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = state.selectedEmployees.length;
    final hasSelection = count > 0;

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _openDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                hasSelection ? Icons.people : Icons.people_outline,
                color: hasSelection
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasSelection ? 'تم اختيار $count موظف' : 'لم يتم اختيار أي موظفين',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasSelection
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (hasSelection)
                TextButton(
                  onPressed: notifier.clearSelectedEmployees,
                  child: const Text('مسح الكل'),
                )
              else
                Icon(
                  Icons.chevron_left,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDialog(BuildContext context) {
    showDialog<List<EmployeeRecord>>(
      context: context,
      builder: (ctx) => _EmployeeSelectionDialog(
        currentSelection: state.selectedEmployees,
      ),
    ).then((result) {
      if (result != null) {
        notifier.setSelectedEmployees(result);
      }
    });
  }
}

// ── Employee Selection Dialog ─────────────────────────────────────────────────

class _EmployeeSelectionDialog extends ConsumerStatefulWidget {
  final List<EmployeeRecord> currentSelection;

  const _EmployeeSelectionDialog({required this.currentSelection});

  @override
  ConsumerState<_EmployeeSelectionDialog> createState() =>
      _EmployeeSelectionDialogState();
}

class _EmployeeSelectionDialogState
    extends ConsumerState<_EmployeeSelectionDialog> {
  late Set<int> _checkedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkedIds = widget.currentSelection.map((e) => e.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختيار الموظفين'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'إغلاق',
            onPressed: () => Navigator.of(context).pop(null),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final allEmployees =
                    employeesAsync.value ?? [];
                final selected = allEmployees
                    .where((e) => _checkedIds.contains(e.id))
                    .toList();
                Navigator.of(context).pop(selected);
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'بحث باسم الموظف، القسم، أو الرقم الوظيفي',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
            Expanded(
              child: employeesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('خطأ في تحميل الموظفين',
                      style: TextStyle(
                          color: theme.colorScheme.error)),
                ),
                data: (employees) {
                  final filtered = _searchQuery.isEmpty
                      ? employees
                      : employees.where((e) {
                          final q = _searchQuery.toLowerCase();
                          return e.name.toLowerCase().contains(q) ||
                              e.department.toLowerCase().contains(q) ||
                              e.employeeNumber.toLowerCase().contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('لا توجد نتائج مطابقة'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final emp = filtered[i];
                      final isChecked = _checkedIds.contains(emp.id);
                      return CheckboxListTile(
                        value: isChecked,
                        onChanged: (_) => setState(() {
                          if (isChecked) {
                            _checkedIds.remove(emp.id);
                          } else {
                            _checkedIds.add(emp.id);
                          }
                        }),
                        title: Text(emp.name),
                        subtitle: Text(
                            '${emp.employeeNumber} • ${emp.department}'),
                        secondary: Chip(
                          label: Text(
                            emp.employmentType == EmploymentType.shift
                                ? 'مناوب'
                                : 'صباحي',
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
