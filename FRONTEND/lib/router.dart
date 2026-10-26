import 'package:flutter/widgets.dart' show ValueKey;
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'providers/auth_provider.dart';
import 'screens/complaint_detail_screen.dart';
import 'screens/complaints_list_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/misc_screens.dart';
import 'screens/register_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/submit_complaint_screen.dart';
import 'screens/users_offices_screen.dart';

/// Routes follow the Activity 6 navigation plan. The redirect is the client-side
/// guard; the Flask API still re-checks the JWT and role on every request.
GoRouter buildRouter(AuthProvider auth) {
  // path -> the only role allowed to open it
  const roleOnly = {
    '/citizen/dashboard': UserRole.citizen,
    '/staff/dashboard': UserRole.staff,
    '/admin/dashboard': UserRole.admin,
    '/submit-complaint': UserRole.citizen,
    '/complaint-tracking': UserRole.citizen,
    '/complaint-review': UserRole.staff,
    '/admin/complaints': UserRole.admin,
    '/reports-analytics': UserRole.admin,
    '/admin/users': UserRole.admin,
  };

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final user = auth.user;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (user == null) return onAuthPage ? null : '/login';
      if (onAuthPage || loc == '/') return user.role.home;

      final only = roleOnly[loc];
      if (only != null && only != user.role) return '/unauthorized';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) =>
            LoginScreen(justRegistered: s.uri.queryParameters['registered'] == '1'),
      ),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/citizen/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/staff/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/admin/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/submit-complaint', builder: (c, s) => const SubmitComplaintScreen()),
      for (final path in const ['/complaint-tracking', '/complaint-review', '/admin/complaints'])
        GoRoute(
          path: path,
          builder: (c, s) {
            final q = s.uri.queryParameters['q'] ?? '';
            return ComplaintsListScreen(key: ValueKey('$path|$q'), initialQuery: q);
          },
        ),
      GoRoute(
        path: '/complaints/:id',
        builder: (c, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          if (id == null) return const UnauthorizedScreen();
          return ComplaintDetailScreen(key: ValueKey('complaint-$id'), id: id);
        },
      ),
      GoRoute(path: '/reports-analytics', builder: (c, s) => const ReportsScreen()),
      GoRoute(path: '/admin/users', builder: (c, s) => const UsersOfficesScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/unauthorized', builder: (c, s) => const UnauthorizedScreen()),
    ],
    errorBuilder: (c, s) => const UnauthorizedScreen(),
  );
}
