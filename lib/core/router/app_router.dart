import 'package:cocheras_nestle_web/presentation/screens/dashboard.dart';
import 'package:cocheras_nestle_web/presentation/screens/garages.dart';
import 'package:cocheras_nestle_web/presentation/screens/login.dart';
import 'package:cocheras_nestle_web/presentation/screens/reports.dart';
import 'package:cocheras_nestle_web/presentation/screens/security.dart';
import 'package:cocheras_nestle_web/presentation/screens/users.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const Login()),
    GoRoute(path: '/dashboard', builder: (context, state) => const Dashboard()),
    GoRoute(path: '/reports', builder: (context, state) => const Reports()),
    GoRoute(path: '/garages', builder: (context, state) => const Garages()),
    GoRoute(path: '/security', builder: (context, state) => const Security()),
    GoRoute(path: '/users', builder: (context, state) => const Users()),
  ],
);
