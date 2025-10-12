import 'package:cocheras_nestle_web/features/garages/providers/garage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class AssignAdminScreen extends ConsumerWidget {
  const AssignAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garagesAsync = ref.watch(garagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Admins')),
      body: garagesAsync.when(
        data: (garages) {
          if (garages.isEmpty) {
            return const Center(child: Text('No hay cocheras disponibles.'));
          }

          return ListView.builder(
            itemCount: garages.length,
            itemBuilder: (_, i) {
              final garage = garages[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(garage.name),
                  subtitle: Text('Admins: ${garage.adminIds.join(', ')}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      // abrir modal para seleccionar usuario
                      // luego llamar:
                      // ref.read(garageRepositoryProvider).assignAdmin(garage.id, userId);
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
