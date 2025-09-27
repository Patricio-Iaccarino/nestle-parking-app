import 'package:cocheras_nestle_web/features/admin/admin_home.dart';
import 'package:cocheras_nestle_web/features/dashboard/dashboard.dart';
// import 'package:cocheras_nestle_web/features/reservations/garages.dart';
import 'package:cocheras_nestle_web/features/auth/login.dart';
// import 'package:cocheras_nestle_web/features/admin/reports.dart';
// import 'package:cocheras_nestle_web/features/security/security.dart';
// import 'package:cocheras_nestle_web/features/admin/users.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/dashboard', builder: (context, state) => const Dashboard()),
    GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
    // GoRoute(path: '/garages', builder: (context, state) => const Garages()),
    // GoRoute(path: '/security', builder: (context, state) => const Security()),
    // GoRoute(path: '/users', builder: (context, state) => const Users()),
  ],
);
