import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';

class AppLayout extends ConsumerWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/users')) return 1;
    if (location.startsWith('/garages')) return 2;
    if (location.startsWith('/reservations')) return 3;
    if (location.startsWith('/reports')) return 4;
    if (location.startsWith('/assign-admins')) return 5; // nueva ruta
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index, bool isSuperAdmin) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/users');
        break;
      case 2:
        context.go('/garages');
        break;
      case 3:
        context.go('/reservations');
        break;
      case 4:
        context.go('/reports');
        break;
      case 5:
        if (isSuperAdmin) context.go('/assign-admins');
        break;
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar sesión?'),
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

    if (result == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _getSelectedIndex(context);
    final authState = ref.watch(authControllerProvider);
    final isSuperAdmin = authState.value?.role == 'superadmin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cocheras Nestlé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onDestinationSelected(context, index, isSuperAdmin),
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Usuarios'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.local_parking),
                label: Text('Cocheras'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.book_online),
                label: Text('Reservas'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.bar_chart),
                label: Text('Reportes'),
              ),
              if (isSuperAdmin)
                const NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings),
                  label: Text('Asignar Admins'),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
