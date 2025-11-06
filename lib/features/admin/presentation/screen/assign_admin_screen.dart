// assign_admin_screen.dart
import 'package:cocheras_nestle_web/features/admin/application/assign_admin_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';


class AssignAdminScreen extends ConsumerStatefulWidget {
  final Establishment establishment;
  const AssignAdminScreen({super.key, required this.establishment});

  @override
  ConsumerState<AssignAdminScreen> createState() => _AssignAdminScreenState();
}

class _AssignAdminScreenState extends ConsumerState<AssignAdminScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // --- 👇 CAMBIO 2: Llamamos al NUEVO controller ---
    Future.microtask(() =>
      ref.read(assignAdminControllerProvider.notifier).loadInitialAdmins()
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 3: Miramos el NUEVO provider para la lista/estado ---
    final state = ref.watch(assignAdminControllerProvider);
    final controller = ref.read(assignAdminControllerProvider.notifier);
    
    // (Aún necesitamos el AdminController para la acción de asignar)
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
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre o email...',
                hintText: 'Escribe para filtrar...',
                suffixIcon: _searchController.text.isEmpty
                    ? const Icon(Icons.search)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          controller.search(''); // <-- Llama al NUEVO controller
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (query) {
                controller.search(query); // <-- Llama al NUEVO controller
                setState(() {}); 
              },
            ),
            const SizedBox(height: 16),
            const Divider(),

            // --- Lista de Resultados ---
            Expanded(
              // --- 👇 CAMBIO 4: Leemos del NUEVO estado ---
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.assignableAdmins.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'No hay usuarios elegibles para asignar.'
                                : 'No se encontraron usuarios que coincidan con "${_searchController.text}".'
                          )
                        )
                      : ListView.builder(
                          itemCount: state.assignableAdmins.length,
                          itemBuilder: (context, index) {
                            final user = state.assignableAdmins[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(user.displayName.isNotEmpty ? user.displayName[0] : '?'),
                                ),
                                title: Text(user.displayName),
                                subtitle: Text("${user.email} (Rol: ${user.role.isEmpty ? 'Sin rol' : user.role})"),
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
                                      // --- 👇 CAMBIO 5: La acción de asignar ---
                                      // (Sigue usando el AdminController, ¡esto está bien!)
                                      await adminController.assignAdmin(user.id, widget.establishment.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar( 
                                          SnackBar(
                                            content: Text('${user.displayName} ahora es admin de ${widget.establishment.name}.'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Refrescamos la lista de admins (por si acaso)
                                        controller.loadInitialAdmins();
                                        // Volvemos a la pantalla anterior
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