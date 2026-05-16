import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/reports/screens/report_detail_screen.dart';
import '../../features/reports/screens/report_generate_screen.dart';
import '../../features/reports/screens/report_screen.dart';
import '../../features/reports/screens/reports_list_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/reports',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              name: 'reports',
              builder: (context, state) => const ReportsListScreen(),
              routes: [
                GoRoute(
                  path: 'generate',
                  name: 'report_generate',
                  builder: (context, state) => const ReportGenerateScreen(),
                ),
                GoRoute(
                  path: ':reportId',
                  name: 'report',
                  builder: (context, state) => ReportScreen(
                    reportId:
                        int.parse(state.pathParameters['reportId']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail/:employeeType/:employeeResultId',
                      name: 'detail',
                      builder: (context, state) => ReportDetailScreen(
                        reportId:
                            int.parse(state.pathParameters['reportId']!),
                        employeeType: state.pathParameters['employeeType']!,
                        employeeResultId: int.parse(
                          state.pathParameters['employeeResultId']!,
                        ),
                      ),
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
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
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
