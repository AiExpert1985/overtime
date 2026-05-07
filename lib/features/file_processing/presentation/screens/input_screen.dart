import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/input_screen_providers.dart';

class InputScreen extends ConsumerWidget {
  const InputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inputScreenProvider);
    final notifier = ref.read(inputScreenProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('الإدخال')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilePickerCard(
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
            const SizedBox(height: 12),
            _FilePickerCard(
              label: 'ملف الموظفين المستهدفين',
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
            const SizedBox(height: 12),
            _FilePickerCard(
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
            const SizedBox(height: 20),
            _DateRangeSection(state: state, notifier: notifier),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state.canGenerate
                  ? () => debugPrint('توليد التقرير — غير منفَّذ بعد')
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'توليد التقرير',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
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

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _buildStatus(theme)),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'معلومات',
                  onPressed: () => _showInfo(context),
                ),
              ],
            ),
            if (cardState is FileCardInvalid) ...[
              const SizedBox(height: 4),
              Text(
                (cardState as FileCardInvalid).errorMessage,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(_buttonLabel),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(ThemeData theme) {
    return switch (cardState) {
      FileCardEmpty() => Text(
          label,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      FileCardValid(:final fileNames) => Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _validLabel(fileNames),
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      FileCardInvalid(:final fileNames) => Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _invalidLabel(fileNames),
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _DatePickerButton(
                label: 'من',
                date: state.startDate,
                onPick: (date) => notifier.setStartDate(date),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DatePickerButton(
                label: 'إلى',
                date: state.endDate,
                onPick: (date) => notifier.setEndDate(date),
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
