import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
 

  const AppLayout({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/users')) return 1;
    if (location.startsWith('/parkings')) return 2;
    if (location.startsWith('/reservations')) return 3;
    if (location.startsWith('/reports')) return 4;

    return 0; // default
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/users');
        break;
      case 2:
        context.go('/parkings');
        break;
      case 3:
        context.go('/reservations');
        break;
      case 4:
        context.go('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cocheras Nestlé Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // futuro: ir a perfil / logout
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Usuarios'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_parking),
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
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16.0), child: child),
          ),
        ],
      ),
    );
  }
}
