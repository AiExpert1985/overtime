import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  final int reportId;

  const ReportScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقرير')),
      body: Center(child: Text('تقرير #$reportId')),
    );
  }
}
