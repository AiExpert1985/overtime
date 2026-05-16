import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReportsListScreen extends ConsumerWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: const Center(child: Text('قائمة التقارير')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.goNamed('report_generate'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
