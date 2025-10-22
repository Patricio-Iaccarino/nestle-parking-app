import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/presentation/screen/assign_Admin_screen.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';

class EstablishmentsScreen extends ConsumerStatefulWidget {
  const EstablishmentsScreen({super.key});

  @override
  ConsumerState<EstablishmentsScreen> createState() =>
      _EstablishmentsScreenState();
}

class _EstablishmentsScreenState extends ConsumerState<EstablishmentsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminControllerProvider.notifier).loadEstablishmentsAndAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);
    final List<AppUser> allUsers = state.users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Establecimientos Nestlé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadEstablishmentsAndAllUsers,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, controller),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.establishments.isEmpty
          ? const Center(child: Text('No hay establecimientos registrados.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2, // Sombra sutil
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Dirección')),
                    DataColumn(label: Text('Tipo')),
                    DataColumn(label: Text('Administrador')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: state.establishments.map((e) {
                    // --- ✨ LÓGICA PARA BUSCAR AL ADMIN ---
                      String adminName = 'Sin asignar';
                      try {
                        // Buscamos en la lista de todos los usuarios
                        final admin = allUsers.firstWhere(
                          (user) => user.role == 'admin' && user.establishmentId == e.id
                        );
                        adminName = admin.displayName;
                      } catch (err) {
                        // Si no encuentra (firstWhere falla), no hacemos nada.
                        // adminName se queda como 'Sin asignar'.
                      }

                    return DataRow(
                      cells: [
                        DataCell(Text(e.name)),
                        DataCell(Text(e.address)),
                        DataCell(Text(e.organizationType)),
                        DataCell(Text(adminName)),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Editar',
                                onPressed: () =>
                                    _showEditDialog(context, controller, e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: 'Eliminar',
                                color: Colors.red,
                                onPressed: () =>
                                    _confirmDelete(context, controller, e.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_add),
                                tooltip: 'Asignar Administrador',
                                color: Colors.blue,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AssignAdminScreen(establishment: e),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    AdminController controller,
  ) async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String orgType = 'DEPARTAMENTAL';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Establecimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Dirección'),
            ),
            DropdownButtonFormField<String>(
              initialValue: orgType,
              items: const [
                DropdownMenuItem(
                  value: 'DEPARTAMENTAL',
                  child: Text('Departamental'),
                ),
                DropdownMenuItem(value: 'UNIFICADO', child: Text('Unificado')),
              ],
              onChanged: (val) => orgType = val ?? 'DEPARTAMENTAL',
              decoration: const InputDecoration(
                labelText: 'Tipo de organización',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final est = Establishment(
                id: '',
                name: nameController.text.trim(),
                address: addressController.text.trim(),
                organizationType: orgType,
                createdAt: DateTime.now(),
              );
              await controller.createEstablishment(est);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller,
    Establishment e,
  ) async {
    final nameController = TextEditingController(text: e.name);
    final addressController = TextEditingController(text: e.address);
    String orgType = e.organizationType;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Establecimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Dirección'),
            ),
            DropdownButtonFormField<String>(
              initialValue: orgType,
              items: const [
                DropdownMenuItem(
                  value: 'DEPARTAMENTAL',
                  child: Text('Departamental'),
                ),
                DropdownMenuItem(value: 'UNIFICADO', child: Text('Unificado')),
              ],
              onChanged: (val) => orgType = val ?? e.organizationType,
              decoration: const InputDecoration(
                labelText: 'Tipo de organización',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = e.copyWith(
                name: nameController.text.trim(),
                address: addressController.text.trim(),
                organizationType: orgType,
              );
              await controller.updateEstablishment(
                updated,
              ); // mismo método para update
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar establecimiento'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este establecimiento? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteEstablishment(id);
    }
  }
}
