import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/reports/screens/report_detail_screen.dart';
import '../../features/reports/screens/report_generate_screen.dart';
import '../../features/reports/screens/report_screen.dart';
import '../../features/reports/screens/reports_list_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const ReportGenerateScreen(),
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const ReportsListScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/report/:reportId',
      name: 'report',
      builder: (context, state) => ReportScreen(
        reportId: int.parse(state.pathParameters['reportId']!),
      ),
      routes: [
        GoRoute(
          path: 'detail/:employeeType/:employeeResultId',
          name: 'detail',
          builder: (context, state) => ReportDetailScreen(
            reportId: int.parse(state.pathParameters['reportId']!),
            employeeType: state.pathParameters['employeeType']!,
            employeeResultId: int.parse(
              state.pathParameters['employeeResultId']!,
            ),
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const Scaffold(
    body: Center(child: Text('الصفحة غير موجودة')),
  ),
);
