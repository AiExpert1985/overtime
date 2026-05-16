import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_provider.dart';
import '../domain/picked_file.dart';
import '../providers/report_generate_provider.dart';

class ReportGenerateScreen extends ConsumerWidget {
  const ReportGenerateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportGenerateProvider);
    final maxRange = ref
            .watch(settingsProvider)
            .whenOrNull(data: (s) => s.maxReportDateRange) ??
        32;

    return Scaffold(
      appBar: AppBar(title: const Text('توليد تقرير')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFileCard(context, ref, state),
                const SizedBox(height: 24),
                _buildDateSection(context, ref, state, maxRange),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: state.isGenerateEnabled ? () {} : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('توليد التقرير',
                      style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    WidgetRef ref,
    ReportGenerateState state,
  ) {
    final notifier = ref.read(reportGenerateProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (state.files.isEmpty)
                  const Text(
                    'ملفات الحضور',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'معلومات',
                  onPressed: () => _showInfoDialog(context),
                ),
              ],
            ),
            if (state.files.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'لم يتم إضافة أي ملفات بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _pickFiles(ref),
                icon: const Icon(Icons.add),
                label: const Text('إضافة ملفات'),
              ),
            ] else ...[
              const SizedBox(height: 4),
              ...state.files.map(
                (file) => _FileRow(
                  file: file,
                  onDelete: () => notifier.removeFile(file.path),
                ),
              ),
              if (state.files.length < 10) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _pickFiles(ref),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة المزيد من الملفات'),
                ),
              ],
            ],
            if (state.filesError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.filesError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(
    BuildContext context,
    WidgetRef ref,
    ReportGenerateState state,
    int maxRange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'من',
                date: state.startDate,
                onTap: () => _pickStartDate(context, ref, maxRange),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DateField(
                label: 'إلى',
                date: state.endDate,
                onTap: () => _pickEndDate(context, ref, maxRange),
              ),
            ),
          ],
        ),
        if (state.dateError != null) ...[
          const SizedBox(height: 8),
          Text(
            state.dateError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFiles(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (result == null) return;
    final paths =
        result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    ref.read(reportGenerateProvider.notifier).addFiles(paths);
  }

  Future<void> _pickStartDate(
      BuildContext context, WidgetRef ref, int maxRange) async {
    final current = ref.read(reportGenerateProvider).startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    ref.read(reportGenerateProvider.notifier).setStartDate(picked, maxRange);
  }

  Future<void> _pickEndDate(
      BuildContext context, WidgetRef ref, int maxRange) async {
    final state = ref.read(reportGenerateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.endDate ?? state.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    ref.read(reportGenerateProvider.notifier).setEndDate(picked, maxRange);
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(
          'ملف Excel يحتوي على ثلاثة أعمدة: اسم الموظف، القسم، التاريخ والوقت.'
          ' يمكن تقديم أكثر من ملف، وكل ملف يمكن أن يحتوي على أكثر من ورقة عمل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onDelete});

  final PickedFile file;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: file.isValidating
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    file.isValid ? Icons.check_circle : Icons.cancel,
                    color: file.isValid
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, overflow: TextOverflow.ellipsis),
                if (file.errorMessage != null)
                  Text(
                    file.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'حذف',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  String _format(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date != null ? _format(date!) : '',
          style: date == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}
