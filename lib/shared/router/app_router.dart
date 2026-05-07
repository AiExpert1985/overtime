import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/file_processing/presentation/screens/input_screen.dart';
import '../../features/reporting/presentation/screens/column_headers_screen.dart';
import '../../features/reporting/presentation/screens/detail_screen.dart';
import '../../features/reporting/presentation/screens/report_screen.dart';
import '../../features/reporting/presentation/screens/reports_list_screen.dart';
import '../../features/reporting/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/input',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/input',
                name: 'input',
                builder: (context, state) => const InputScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) => const ReportsListScreen(),
                routes: [
                  GoRoute(
                    path: ':reportId',
                    name: 'report',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['reportId']!);
                      return ReportScreen(reportId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'detail/:employeeName',
                        name: 'detail',
                        builder: (context, state) {
                          final id =
                              int.parse(state.pathParameters['reportId']!);
                          final name = state.pathParameters['employeeName']!;
                          return DetailScreen(
                              reportId: id, employeeName: name);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'column-headers',
                    name: 'column_headers',
                    builder: (context, state) => const ColumnHeadersScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('الصفحة غير موجودة')),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});

class _AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file),
            label: 'الإدخال',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'التقارير',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
