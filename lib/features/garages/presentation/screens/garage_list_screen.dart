import 'package:cocheras_nestle_web/features/garages/providers/garage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'garage_form_screen.dart';

class GarageListScreen extends ConsumerWidget {
  const GarageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garagesAsync = ref.watch(garagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cocheras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GarageFormScreen()),
              );
              ref.invalidate(garagesProvider); // refresca al volver
            },
          ),
        ],
      ),
      body: garagesAsync.when(
        data: (garages) {
          if (garages.isEmpty) {
            return const Center(child: Text('No hay cocheras registradas.'));
          }
          return ListView.builder(
            itemCount: garages.length,
            itemBuilder: (context, index) {
              final garage = garages[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(garage.name),
                  subtitle: Text(
                    '${garage.address} — Capacidad: ${garage.capacity}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Editar',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GarageFormScreen(garage: garage),
                            ),
                          );
                          ref.invalidate(garagesProvider);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Eliminar',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Eliminar cochera'),
                              content: Text(
                                '¿Seguro que querés eliminar "${garage.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            final repo = ref.read(garageRepositoryProvider);
                            await repo.deleteGarage(garage.id);
                            ref.invalidate(garagesProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cochera eliminada'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
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
