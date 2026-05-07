import 'package:flutter/material.dart';

class ColumnHeadersScreen extends StatelessWidget {
  const ColumnHeadersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رؤوس الأعمدة')),
      body: const Center(child: Text('إدارة رؤوس الأعمدة')),
    );
  }
}
