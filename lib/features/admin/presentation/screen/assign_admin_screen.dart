import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';

class AssignAdminScreen extends ConsumerWidget {
  final Establishment establishment;

  const AssignAdminScreen({super.key, required this.establishment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el estado completo de nuestro AdminController
    final adminState = ref.watch(adminControllerProvider);
    // Obtenemos el controller para poder llamar a sus métodos
    final adminController = ref.read(adminControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('Asignar Admin a: ${establishment.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Barra de Búsqueda ---
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o email...',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                // Llamamos a la nueva función de búsqueda en nuestro controller
                adminController.searchUsers(query);
              },
            ),
            const SizedBox(height: 16),
            const Divider(),

            // --- Lista de Resultados ---
            Expanded(
              child: adminState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : adminState.searchResults.isEmpty
                  ? const Center(child: Text('No se encontraron usuarios.'))
                  : ListView.builder(
                      itemCount: adminState.searchResults.length,
                      itemBuilder: (context, index) {
                        final user = adminState.searchResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0]
                                    : '?',
                              ),
                            ),
                            title: Text(user.displayName),
                            subtitle: Text(user.email),
                            trailing: ElevatedButton(
                              child: const Text('Asignar'),
                              onPressed: () async {
                                // Mostramos un diálogo de confirmación
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar Asignación'),
                                    content: Text(
                                      '¿Seguro que deseas nombrar a ${user.displayName} como administrador de ${establishment.name}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Asignar'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  // ¡Usamos el método que YA TENÍAS en tu controller!
                                  await adminController.assignAdmin(
                                    user.id,
                                    establishment.id,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${user.displayName} ha sido nombrado administrador.',
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
