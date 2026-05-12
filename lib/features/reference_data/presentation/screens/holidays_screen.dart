import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/holiday_record.dart';
import '../providers/reference_data_providers.dart';

class HolidaysScreen extends ConsumerWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(holidaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('العطل')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context, ref, null),
        tooltip: 'إضافة عطلة',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('خطأ في تحميل العطل',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (holidays) {
          if (holidays.isEmpty) {
            return const Center(
              child: Text('لم يتم إضافة أي عطل رسمية بعد',
                  style: TextStyle(fontSize: 16)),
            );
          }
          return _HolidaysTable(holidays: holidays);
        },
      ),
    );
  }

  void _showDialog(
      BuildContext context, WidgetRef ref, HolidayRecord? holiday) {
    showDialog<void>(
      context: context,
      builder: (_) => _HolidayDialog(
        holiday: holiday,
        notifier: ref.read(holidaysProvider.notifier),
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _HolidaysTable extends ConsumerWidget {
  final List<HolidayRecord> holidays;

  const _HolidaysTable({required this.holidays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('المناسبة')),
            DataColumn(label: Text('')),
          ],
          rows: holidays.map((holiday) {
            return DataRow(cells: [
              DataCell(Text(dateFormat.format(holiday.date))),
              DataCell(Text(holiday.occasion)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'تعديل',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showDialog(context, ref, holiday),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: theme.colorScheme.error),
                    tooltip: 'حذف',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(context, ref, holiday),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  void _showDialog(
      BuildContext context, WidgetRef ref, HolidayRecord? holiday) {
    showDialog<void>(
      context: context,
      builder: (_) => _HolidayDialog(
        holiday: holiday,
        notifier: ref.read(holidaysProvider.notifier),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, HolidayRecord holiday) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العطلة'),
        content: Text(
            'هل تريد حذف "${holiday.occasion} — ${dateFormat.format(holiday.date)}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(holidaysProvider.notifier).deleteHoliday(holiday.id);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit Dialog ─────────────────────────────────────────────────────────

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({this.holiday, required this.notifier});

  final HolidayRecord? holiday;
  final HolidaysNotifier notifier;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  DateTime? _date;
  late final _occasionCtrl =
      TextEditingController(text: widget.holiday?.occasion ?? '');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.holiday?.date;
    _occasionCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _occasionCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _date != null && _occasionCtrl.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final holiday = widget.holiday;
    if (holiday == null) {
      await widget.notifier.addHoliday(
        date: _date!,
        occasion: _occasionCtrl.text.trim(),
      );
    } else {
      await widget.notifier.updateHoliday(
        holiday.id,
        date: _date!,
        occasion: _occasionCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.holiday != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      title: Text(isEdit ? 'تعديل عطلة' : 'إضافة عطلة'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(_date != null
                  ? dateFormat.format(_date!)
                  : 'اختر التاريخ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _occasionCtrl,
              autofocus: _date != null,
              decoration: const InputDecoration(labelText: 'المناسبة'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
