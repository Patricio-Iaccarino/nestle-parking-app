// assign_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';


class AssignAdminScreen extends ConsumerStatefulWidget { // ✨ Convertido a StatefulWidget
  final Establishment establishment;
  const AssignAdminScreen({super.key, required this.establishment});

  @override
  ConsumerState<AssignAdminScreen> createState() => _AssignAdminScreenState();
}

class _AssignAdminScreenState extends ConsumerState<AssignAdminScreen> { // ✨ Estado
  final TextEditingController _searchController = TextEditingController(); // Controlador para el TextField

  @override
  void initState() {
    super.initState();
    // ✨ Cargamos la lista inicial al entrar en la pantalla
    Future.microtask(() =>
      ref.read(adminControllerProvider.notifier).loadInitialAssignableUsers()
    );
  }

  @override
  void dispose() {
    _searchController.dispose(); // Limpiamos el controlador
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminControllerProvider);
    final adminController = ref.read(adminControllerProvider.notifier);
  

    return Scaffold(
      appBar: AppBar(
        title: Text('Asignar Admin a: ${widget.establishment.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Barra de Búsqueda ---
            TextField(
              controller: _searchController, // Usamos el controlador
              decoration: InputDecoration(
                labelText: 'Buscar por nombre o email...',
                hintText: 'Escribe para filtrar...',
                suffixIcon: _searchController.text.isEmpty
                  ? const Icon(Icons.search)
                  : IconButton( // Botón para limpiar la búsqueda
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        adminController.searchUsers(''); // Llama con query vacía
                      },
                    ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (query) {
                // Llamamos a la función de búsqueda en cada cambio
                adminController.searchUsers(query);
                // Forzamos reconstrucción para actualizar el ícono de limpiar
                setState(() {}); 
              },
            ),
            const SizedBox(height: 16),
            const Divider(),

            // --- Lista de Resultados ---
            Expanded(
              child: adminState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : adminState.searchResults.isEmpty
                      // ✨ LÓGICA DEL MENSAJE: Solo si hay texto de búsqueda
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'No hay usuarios elegibles para asignar.' // Mensaje inicial si la lista está vacía
                                : 'No se encontraron usuarios que coincidan con "${_searchController.text}".' // Mensaje si el filtro no da resultados
                          )
                        )
                      : ListView.builder(
                          itemCount: adminState.searchResults.length,
                          itemBuilder: (context, index) {
                            final user = adminState.searchResults[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(user.displayName.isNotEmpty ? user.displayName[0] : '?'),
                                ),
                                title: Text(user.displayName),
                                subtitle: Text("${user.email} (Rol: ${user.role.isEmpty ? 'Sin rol' : user.role})"), // Muestra rol actual
                                trailing: ElevatedButton(
                                  child: const Text('Asignar'),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Confirmar Asignación'),
                                        content: Text('¿Asignar a ${user.displayName} como admin de ${widget.establishment.name}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Confirmar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await adminController.assignAdmin(user.id, widget.establishment.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(  
                                          SnackBar(
                                            content: Text('${user.displayName} ahora es admin de ${widget.establishment.name}.'),
                                            backgroundColor: Colors.green,
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