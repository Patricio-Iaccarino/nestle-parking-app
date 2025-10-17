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
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    // Para el superadmin, el índice siempre será 0 porque solo hay una opción
    final selectedIndex = location.startsWith('/establishments') ? 0 : 0;

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        context.go('/establishments');
      },
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.business_rounded),
          label: Text('Establecimientos'),
        ),
      ],
    );
  }
}

class _AdminNavigationRail extends ConsumerWidget {
  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/departments')) return 1;
    if (location.startsWith('/reservations')) return 2;
    if (location.startsWith('/reports')) return 3;
    return 0;
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
          // Opcional: Mostrar un error si por alguna razón el admin no tiene ID
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se encontró el ID del establecimiento.'),
            ),
          );
        }
        break;
      case 2:
        context.go('/reservations');
        break;
      case 3:
        context.go('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✨ Añadido WidgetRef
    return NavigationRail(
      selectedIndex: _getSelectedIndex(context),
      onDestinationSelected: (index) =>
          _onDestinationSelected(context, ref, index), // ✨ Pasamos ref
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
