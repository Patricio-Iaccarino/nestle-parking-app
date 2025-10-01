//import 'package:cocheras_nestle_web/features/admin/admin_screen.dart';
import 'package:cocheras_nestle_web/core/widgets/app_layout.dart';
import 'package:cocheras_nestle_web/features/admin/reports_screen.dart';
import 'package:cocheras_nestle_web/features/dashboard/dashboard_screen.dart';
import 'package:cocheras_nestle_web/features/reservations/parking_screen.dart';
import 'package:cocheras_nestle_web/features/reservations/reservations_screen.dart';
import 'package:cocheras_nestle_web/features/auth/login_screen.dart';
// import 'package:cocheras_nestle_web/features/admin/reports.dart';
// import 'package:cocheras_nestle_web/features/security/security.dart';
import 'package:cocheras_nestle_web/features/admin/users_screen.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppLayout(child: child); // layout fijo
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const Dashboard(),
        ),
        //GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersScreen(),
        ),
        GoRoute(
          path: '/parkings',
          builder: (context, state) => const ParkingScreen(),
        ),
        GoRoute(
          path: '/reservations',
          builder: (context, state) => const ReservationsScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ), //ReportsScreen()),
      ],
    ),
  ],
);
