import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/report.dart';
import '../providers/reports_provider.dart';

class ReportsListScreen extends ConsumerWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل التقارير: $e')),
        data: (reports) => reports.isEmpty
            ? const Center(child: Text('لا توجد تقارير سابقة'))
            : _ReportsTable(reports: reports),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.goNamed('report_generate'),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class _ReportsTable extends StatelessWidget {
  const _ReportsTable({required this.reports});

  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TableHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: reports.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _ReportRow(report: reports[index]),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('تاريخ الإنشاء', style: style)),
          Expanded(flex: 2, child: Text('من', style: style)),
          Expanded(flex: 2, child: Text('إلى', style: style)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datetimeFmt = DateFormat('dd/MM/yyyy HH:mm');
    final dateFmt = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: () => context.goNamed(
        'report',
        pathParameters: {'reportId': '${report.id}'},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(datetimeFmt.format(report.generationDatetime)),
            ),
            Expanded(
              flex: 2,
              child: Text(dateFmt.format(report.rangeStart)),
            ),
            Expanded(
              flex: 2,
              child: Text(dateFmt.format(report.rangeEnd)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقرير'),
        content: const Text('هل أنت متأكد من حذف هذا التقرير؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(reportsProvider.notifier).deleteReport(report.id);
    }
  }
}
