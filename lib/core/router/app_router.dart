import 'package:cocheras_nestle_web/core/widgets/app_layout.dart';
import 'package:cocheras_nestle_web/features/departments/presentation/screens/departments_screen.dart';
import 'package:cocheras_nestle_web/features/establishments/presentation/screens/establishments_screen.dart';
import 'package:cocheras_nestle_web/features/establishments/presentation/screens/reports_screen.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/dashboard/dashboard_screen.dart';
import 'package:cocheras_nestle_web/features/parking_spots/presentation/screens/parking_spots_screen.dart';
import 'package:cocheras_nestle_web/features/reservations/presentation/screens/reservations_screen.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/login_screen.dart';
import 'package:cocheras_nestle_web/features/users/presentation/users_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.value;

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = user != null;
      final isLoggingIn = state.uri.path == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) {
        if (user.role == 'superadmin') {
          return '/establishments';
        } else {
          return '/dashboard';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppLayout(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/establishments',
            builder: (context, state) => const EstablishmentsScreen(),
          ),
          GoRoute(
            path: '/departments/:establishmentId',
            builder: (context, state) {
              final establishmentId = state.pathParameters['establishmentId']!;
              return DepartmentsScreen(establishmentId: establishmentId);
            },
          ),

          GoRoute(
            path:
                '/establishments/:establishmentId/departments/:departmentId/spots',
            builder: (context, state) {
              final establishmentId = state.pathParameters['establishmentId']!;
              final departmentId = state.pathParameters['departmentId']!;
              // Pasamos ambos IDs a la pantalla
              return ParkingSpotsScreen(
                establishmentId: establishmentId,
                departmentId: departmentId,
                departmentName:
                    state.uri.queryParameters['departmentName'] ??
                    'Departamento',
              );
            },
          ),
          GoRoute(
            path:
                '/establishments/:establishmentId/departments/:departmentId/users',
            builder: (context, state) {
              // Extraemos ambos parámetros de la URL
              final establishmentId = state.pathParameters['establishmentId']!;
              final departmentId = state.pathParameters['departmentId']!;

              // Se los pasamos a la pantalla de Usuarios
              return UsersScreen(
                establishmentId: establishmentId,
                departmentId: departmentId,
              );
            },
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
        ],
      ),
    ],
  );
});
