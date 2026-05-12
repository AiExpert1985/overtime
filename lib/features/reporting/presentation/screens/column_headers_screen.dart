import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/column_headers_repository.dart';
import '../providers/column_headers_providers.dart';

class ColumnHeadersScreen extends ConsumerWidget {
  const ColumnHeadersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(columnHeadersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة رؤوس الأعمدة')),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في التحميل: $e')),
        data: (headers) => _ColumnHeadersBody(headers: headers),
      ),
    );
  }
}

class _ColumnHeadersBody extends StatelessWidget {
  final Map<String, Map<String, List<ColumnHeaderItem>>> headers;

  const _ColumnHeadersBody({required this.headers});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FileTypeSection(
                title: 'ملف الحضور',
                fileType: 'attendance',
                fieldLabels: const {
                  'employee_name': 'عمود اسم الموظف',
                  'datetime': 'عمود التاريخ والوقت',
                },
                headers: headers['attendance'] ?? {},
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileTypeSection extends StatelessWidget {
  final String title;
  final String fileType;
  final Map<String, String> fieldLabels;
  final Map<String, List<ColumnHeaderItem>> headers;

  const _FileTypeSection({
    required this.title,
    required this.fileType,
    required this.fieldLabels,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...fieldLabels.entries.map((e) => _FieldSection(
              fileType: fileType,
              fieldKey: e.key,
              fieldLabel: e.value,
              items: headers[e.key] ?? [],
            )),
      ],
    );
  }
}

class _FieldSection extends ConsumerWidget {
  final String fileType;
  final String fieldKey;
  final String fieldLabel;
  final List<ColumnHeaderItem> items;

  const _FieldSection({
    required this.fileType,
    required this.fieldKey,
    required this.fieldLabel,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(columnHeadersProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(fieldLabel,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddDialog(context, notifier),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...items.map((item) => _HeaderItemRow(
                    item: item,
                    fileType: fileType,
                    fieldKey: fieldKey,
                    notifier: notifier,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, ColumnHeadersNotifier notifier) async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('إضافة قيمة — $fieldLabel'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'اسم العمود',
              errorText: errorText,
            ),
            onChanged: (_) { if (errorText != null) setState(() => errorText = null); },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final err = await notifier.addHeader(fileType, fieldKey, controller.text);
                if (err != null) {
                  setState(() => errorText = err);
                } else {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderItemRow extends StatelessWidget {
  final ColumnHeaderItem item;
  final String fileType;
  final String fieldKey;
  final ColumnHeadersNotifier notifier;

  const _HeaderItemRow({
    required this.item,
    required this.fileType,
    required this.fieldKey,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (item.isDefault)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.lock_outline,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
            )
          else
            const SizedBox(width: 20),
          Expanded(
            child: Text(
              item.headerValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: item.isDefault
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (!item.isDefault) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: 'تعديل',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _showEditDialog(context),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 16, color: theme.colorScheme.error),
              tooltip: 'حذف',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: item.headerValue);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تعديل القيمة'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'اسم العمود',
              errorText: errorText,
            ),
            onChanged: (_) { if (errorText != null) setState(() => errorText = null); },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final err = await notifier.updateHeader(
                    item.id, fileType, fieldKey, controller.text);
                if (err != null) {
                  setState(() => errorText = err);
                } else {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القيمة'),
        content: Text('هل تريد حذف "${item.headerValue}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.deleteHeader(item.id);
  }
}
