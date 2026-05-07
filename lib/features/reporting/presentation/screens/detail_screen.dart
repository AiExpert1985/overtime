import 'package:flutter/material.dart';

class DetailScreen extends StatelessWidget {
  final int reportId;
  final String employeeName;

  const DetailScreen({
    super.key,
    required this.reportId,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التفاصيل')),
      body: Center(child: Text('تفاصيل $employeeName')),
    );
  }
}
