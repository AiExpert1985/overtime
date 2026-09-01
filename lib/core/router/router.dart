import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/reports/screens/report_detail_screen.dart';
import '../../features/reports/screens/report_generate_screen.dart';
import '../../features/reports/screens/report_screen.dart';
import '../../features/reports/screens/report_undetected_screen.dart';
import '../../features/reports/screens/reports_list_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

// Each role's landing screen once logged in — audit skips report generation
// entirely and lands on its history list; admin/generate land on generation.
String homeLocationFor(UserRole role) =>
    role == UserRole.audit ? '/reports' : '/';

// Bridges currentUserProvider (Riverpod) into something GoRouter's
// refreshListenable can listen to, so a login/logout re-runs redirect.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier();
  ref.listen(currentUserProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final role = ref.read(currentUserProvider);
      final location = state.matchedLocation;

      if (role == null) {
        return location == '/login' ? null : '/login';
      }
      if (location == '/login') return homeLocationFor(role);
      // Audit is reports-only: no report generation.
      if (role == UserRole.audit && location == '/') return '/reports';
      // Settings is admin-only.
      if (location == '/settings' && role != UserRole.admin) {
        return homeLocationFor(role);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
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
          GoRoute(
            path: 'undetected',
            name: 'undetected',
            builder: (context, state) => ReportUndetectedScreen(
              reportId: int.parse(state.pathParameters['reportId']!),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('الصفحة غير موجودة'))),
  );
});
