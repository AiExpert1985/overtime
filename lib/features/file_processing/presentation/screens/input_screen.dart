import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../reporting/presentation/providers/report_generation_providers.dart';
import '../../../reporting/presentation/providers/report_providers.dart';
import '../providers/input_screen_providers.dart';

class InputScreen extends ConsumerWidget {
  const InputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inputScreenProvider);
    final notifier = ref.read(inputScreenProvider.notifier);
    final genState = ref.watch(generationProvider);
    final isLoading = genState is GenerationLoading;

    ref.listen<InputScreenState>(inputScreenProvider, (prev, next) {
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
        notifier.clearError();
      }
    });

    ref.listen<GenerationState>(generationProvider, (prev, next) {
      switch (next) {
        case GenerationUnmatchedReview(:final unmatchedNames):
          _showUnmatchedDialog(context, ref, unmatchedNames);
        case GenerationSuccess(:final reportId):
          ref.read(reportsVersionProvider.notifier).increment();
          notifier.reset();
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

    return Scaffold(
      appBar: AppBar(title: const Text('الإدخال')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FileCardsRow(state: state, notifier: notifier),
            const SizedBox(height: 28),
            _DateRangeSection(state: state, notifier: notifier),
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 260,
                child: FilledButton(
                  onPressed: (state.canGenerate && !isLoading)
                      ? () => ref.read(generationProvider.notifier).generate(
                            attendance: state.attendanceData,
                            employees: state.employeesData,
                            holidays: state.holidaysData,
                            startDate: state.startDate!,
                            endDate: state.endDate!,
                          )
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnmatchedDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> names,
  ) {
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
                      _exportMessage = path != null
                          ? 'تم التصدير: $path'
                          : 'تعذّر التصدير';
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

// ── File Cards Row ────────────────────────────────────────────────────────────

class _FileCardsRow extends StatelessWidget {
  final InputScreenState state;
  final InputScreenNotifier notifier;

  const _FileCardsRow({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = (constraints.maxWidth * 0.6).clamp(540.0, 900.0);
        final cardWidth = (rowWidth - 24) / 3;

        return Center(
          child: SizedBox(
            width: rowWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _FilePickerCard(
                    label: 'ملف الحضور',
                    infoTitle: 'هيكل ملف الحضور',
                    infoBody:
                        'ملف Excel يحتوي على عمودين:\n\n'
                        '• اسم الموظف\n'
                        '• التاريخ والوقت\n\n'
                        'يمكن تقديم أكثر من ملف، وكل ملف يمكن أن يحتوي على أكثر من ورقة عمل.',
                    entries: state.attendanceViews,
                    cardType: FileCardType.attendance,
                    onAddFiles: notifier.addAttendanceFiles,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: cardWidth,
                  child: _FilePickerCard(
                    label: 'ملف الموظفين',
                    infoTitle: 'هيكل ملف الموظفين',
                    infoBody:
                        'ملف Excel يحتوي على 3 أعمدة:\n\n'
                        '• اسم الموظف\n'
                        '• نوع التوظيف (مناوب أو صباحي)\n'
                        '• القسم\n\n'
                        'يمكن تقديم أكثر من ملف.',
                    entries: state.employeesViews,
                    cardType: FileCardType.employees,
                    onAddFiles: notifier.addEmployeesFiles,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: cardWidth,
                  child: _FilePickerCard(
                    label: 'ملف العطل الرسمية',
                    infoTitle: 'هيكل ملف العطل',
                    infoBody:
                        'ملف Excel يحتوي على عمودين:\n\n'
                        '• التاريخ\n'
                        '• مناسبة العطلة\n\n'
                        'يمكن تقديم أكثر من ملف.',
                    entries: state.holidaysViews,
                    cardType: FileCardType.holidays,
                    onAddFiles: notifier.addHolidaysFiles,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── File Picker Card ──────────────────────────────────────────────────────────

class _FilePickerCard extends StatelessWidget {
  final String label;
  final String infoTitle;
  final String infoBody;
  final List<FileEntryView> entries;
  final FileCardType cardType;
  final VoidCallback onAddFiles;

  const _FilePickerCard({
    required this.label,
    required this.infoTitle,
    required this.infoBody,
    required this.entries,
    required this.cardType,
    required this.onAddFiles,
  });

  bool get _isEmpty => entries.isEmpty;
  bool get _allValid => entries.isNotEmpty && entries.every((e) => e.isValid);
  int get _invalidCount => entries.where((e) => !e.isValid).length;

  Color? _cardColor(ThemeData theme) {
    if (_isEmpty) return null;
    if (_allValid) return Colors.green.shade50;
    return theme.colorScheme.errorContainer.withValues(alpha: 0.25);
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
            // Header row: label/status + info button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeader(context, theme)),
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
            // Clickable file count row (shown when files exist)
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
              onPressed: onAddFiles,
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

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    if (_isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String get _statusLabel {
    final count = entries.length;
    final countLabel = count == 1 ? 'ملف واحد' : '$count ملفات';
    if (_allValid) return '$countLabel • صالحة';
    if (_invalidCount == count) return '$countLabel • غير صالحة';
    return '$countLabel • $_invalidCount غير صالح';
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(infoTitle),
        content: Text(infoBody),
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
      builder: (ctx) => _FileListDialog(
        title: label,
        cardType: cardType,
      ),
    );
  }
}

// ── File List Dialog ──────────────────────────────────────────────────────────

class _FileListDialog extends ConsumerWidget {
  final String title;
  final FileCardType cardType;

  const _FileListDialog({required this.title, required this.cardType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inputScreenProvider);
    final notifier = ref.read(inputScreenProvider.notifier);

    final entries = switch (cardType) {
      FileCardType.attendance => state.attendanceViews,
      FileCardType.employees => state.employeesViews,
      FileCardType.holidays => state.holidaysViews,
    };

    void removeAt(int index) {
      switch (cardType) {
        case FileCardType.attendance:
          notifier.removeAttendanceFile(index);
        case FileCardType.employees:
          notifier.removeEmployeesFile(index);
        case FileCardType.holidays:
          notifier.removeHolidaysFile(index);
      }
    }

    // Auto-close when all files are removed
    if (entries.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 460,
        child: entries.isEmpty
            ? const SizedBox(height: 48)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Column headers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'اسم الملف',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          'الحالة',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                      itemBuilder: (ctx, i) {
                        final entry = entries[i];
                        return _FileRow(
                          entry: entry,
                          onRemove: () => removeAt(i),
                        );
                      },
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

// ── File Row (inside dialog) ──────────────────────────────────────────────────

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
              padding: const EdgeInsets.only(left: 0, right: 40),
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
  final InputScreenState state;
  final InputScreenNotifier notifier;

  const _DateRangeSection({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.dateRangeError;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
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
        ),
      ),
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
