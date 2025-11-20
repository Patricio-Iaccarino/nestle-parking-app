import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';

class AppLayout extends ConsumerWidget {
  final Widget child;
  const AppLayout({super.key, required this.child});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cierre de sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isSuperAdmin = authState.value?.role == 'superadmin';
    final user = authState.value;
    final userRole = user?.role ?? '';
    final establishmentName = user?.establishmentName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (userRole == 'admin' && establishmentName.isNotEmpty)
              ? 'Cocheras Nestlé - $establishmentName'
              : 'Cocheras Nestlé',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFFD91E28),
        foregroundColor: Colors.white,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade700,
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  label: Text(
                    user.displayName.isNotEmpty ? user.displayName : user.email,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isSuperAdmin)
            _SuperAdminNavigationRail()
          else
            _AdminNavigationRail(),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16.0), child: child),
          ),
        ],
      ),
    );
  }
}

class _SuperAdminNavigationRail extends StatelessWidget {
  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/establishments')) return 0;
    if (location.startsWith('/admins')) return 1;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/establishments');
        break;
      case 1:
        context.go('/admins');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: _getSelectedIndex(context),
      onDestinationSelected: (index) => _onDestinationSelected(context, index),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.business_rounded),
          label: Text('Establecimientos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: Text('Admins'),
        ),
      ],
    );
  }
}

// ======================================================
// ADMIN NAVIGATION RAIL
// ======================================================

class _AdminNavigationRail extends ConsumerWidget {
  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/establishments/departments')) {
        return 1; // Selecciona 'Departamentos'
    }

   
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/departments')) return 1;
    if (location.startsWith('/users')) return 2;
    if (location.startsWith('/parking-spots')) return 3;
    if (location.startsWith('/reservations')) return 4;
    if (location.startsWith('/reports')) return 5;

    return 0; // Default a Dashboard
  }

  void _onDestinationSelected(BuildContext context, WidgetRef ref, int index) {
    final user = ref.read(authControllerProvider).value;
    final establishmentId = user?.establishmentId;

    switch (index) {
      case 0:
        context.go('/dashboard');
        break;

      case 1: // --- DEPARTAMENTOS ---
        if (establishmentId != null) {
          context.go('/departments/$establishmentId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se encontró el ID del establecimiento.'),
            ),
          );
        }
        break;

      case 2: // --- USUARIOS ---
        context.go('/users');
        break;

      case 3: // --- COCHERAS ---
        context.go('/parking-spots');
        break;

      case 4: // --- RESERVAS ---
        context.go('/reservations');
        break;

      case 5: // --- REPORTES ---
        context.go('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      selectedIndex: _getSelectedIndex(context),
      onDestinationSelected: (index) =>
          _onDestinationSelected(context, ref, index),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.apartment),
          label: Text('Departamentos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people_alt_rounded),
          label: Text('Usuarios'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_parking_rounded),
          label: Text('Cocheras'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.book_online),
          label: Text('Reservas'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bar_chart),
          label: Text('Reportes'),
        ),
      ],
    );
  }
}
