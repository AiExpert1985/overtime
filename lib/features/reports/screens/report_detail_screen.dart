import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportDetailScreen extends ConsumerWidget {
  final int reportId;
  final String employeeType;
  final int employeeResultId;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.employeeType,
    required this.employeeResultId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(child: Text('تفاصيل الموظف #$employeeResultId')),
    );
  }
}
