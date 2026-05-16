import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportGenerateScreen extends ConsumerWidget {
  const ReportGenerateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('توليد تقرير')),
    );
  }
}
