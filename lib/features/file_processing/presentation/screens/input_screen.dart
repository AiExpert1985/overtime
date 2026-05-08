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
        // Occupy ~60% of available width, clamped between 540 and 900px.
        final rowWidth = (constraints.maxWidth * 0.6).clamp(540.0, 900.0);
        final cardWidth = (rowWidth - 24) / 3; // 24 = 2 gaps of 12px

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
                    cardState: state.attendanceState,
                    isMultiFile: true,
                    onPick: notifier.pickAttendanceFiles,
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
                    cardState: state.employeesState,
                    isMultiFile: true,
                    onPick: notifier.pickEmployeesFiles,
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
                        '• مناسبة العطلة',
                    cardState: state.holidaysState,
                    isMultiFile: false,
                    onPick: notifier.pickHolidaysFile,
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
  final FileCardState cardState;
  final bool isMultiFile;
  final VoidCallback onPick;

  const _FilePickerCard({
    required this.label,
    required this.infoTitle,
    required this.infoBody,
    required this.cardState,
    required this.isMultiFile,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = switch (cardState) {
      FileCardValid() => Colors.green.shade50,
      FileCardInvalid() => theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      FileCardEmpty() => null,
    };

    return Card(
      elevation: 1,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStatus(theme)),
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
            if (cardState is FileCardInvalid) ...[
              const SizedBox(height: 6),
              Text(
                (cardState as FileCardInvalid).errorMessage,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(_buttonLabel, overflow: TextOverflow.ellipsis),
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

  Widget _buildStatus(ThemeData theme) {
    return switch (cardState) {
      FileCardEmpty() => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      FileCardValid(:final fileNames) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _validLabel(fileNames),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      FileCardInvalid(:final fileNames) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fileNames.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _invalidLabel(fileNames),
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    };
  }

  String get _buttonLabel => switch (cardState) {
        FileCardEmpty() => isMultiFile ? 'اختر ملفات' : 'اختر ملفاً',
        FileCardValid() => isMultiFile ? 'تغيير الملفات' : 'تغيير الملف',
        FileCardInvalid() =>
          isMultiFile ? 'اختر ملفات أخرى' : 'اختر ملفاً آخر',
      };

  String _validLabel(List<String> names) {
    if (names.length == 1) return names.first;
    return '${names.length} ملفات';
  }

  String _invalidLabel(List<String> names) {
    if (names.length == 1) return names.first;
    return '${names.length} ملفات';
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
