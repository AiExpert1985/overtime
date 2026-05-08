import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/report_providers.dart';

class ReportsListScreen extends ConsumerWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(reportsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: listAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('خطأ في تحميل التقارير',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد تقارير سابقة',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final dateFormat = DateFormat('yyyy/MM/dd');
              final dtFormat = DateFormat('yyyy/MM/dd  HH:mm');

              return ListTile(
                title: Text(
                  '${dateFormat.format(report.rangeStart)} — ${dateFormat.format(report.rangeEnd)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'تاريخ التوليد: ${dtFormat.format(report.generationDatetime)}'
                  '   •   ${report.totalEmployees} موظف',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف',
                  onPressed: () =>
                      _confirmDelete(context, ref, report.id),
                ),
                onTap: () => context.goNamed(
                  'report',
                  pathParameters: {'reportId': report.id.toString()},
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int reportId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقرير'),
        content: const Text('هل تريد حذف هذا التقرير نهائياً؟'),
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
              ref.read(reportsListProvider.notifier).deleteReport(reportId);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
