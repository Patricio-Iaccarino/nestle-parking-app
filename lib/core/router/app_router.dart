import 'package:cocheras_nestle_web/core/widgets/app_layout.dart';
import 'package:cocheras_nestle_web/features/admin/presentation/screens/assign_admin_screen.dart';
import 'package:cocheras_nestle_web/features/admin/presentation/screens/reports_screen.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/dashboard/dashboard_screen.dart';
import 'package:cocheras_nestle_web/features/garages/presentation/screens/garage_list_screen.dart';
import 'package:cocheras_nestle_web/features/reservations/presentation/screens/reservations_screen.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/login_screen.dart';
import 'package:cocheras_nestle_web/features/admin/presentation/screens/users_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.value;

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/login',
    redirect: (context, state) {
      // No logueado
      if (user == null && state.uri.path != '/login') return '/login';
      // Logueado intenta ir a login
      if (user != null && state.uri.path == '/login') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppLayout(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Dashboard(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
            redirect: (context, state) =>
                (user?.role != 'superadmin') ? '/dashboard' : null,
          ),
          GoRoute(
            path: '/garages',
            builder: (context, state) => const GarageListScreen(),
            redirect: (context, state) =>
                (user == null ||
                    (user.role != 'superadmin' && user.role != 'admin'))
                ? '/dashboard'
                : null,
          ),
          GoRoute(
            path: '/reservations',
            builder: (context, state) => const ReservationsScreen(),
            redirect: (context, state) =>
                (user == null ||
                    (user.role != 'superadmin' && user.role != 'admin'))
                ? '/dashboard'
                : null,
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
            redirect: (context, state) =>
                (user?.role != 'superadmin') ? '/dashboard' : null,
          ),
          GoRoute(
            path: '/assign-admins',
            builder: (context, state) => const AssignAdminScreen(),
          ),
        ],
      ),
    ],
  );
});
