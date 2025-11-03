import 'package:cocheras_nestle_web/features/establishments/application/establishments_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/admin/presentation/screen/assign_Admin_screen.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
// Importamos el nuevo controller

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
    // El 'initState' solo carga los 'users'
    // El 'establishmentsControllerProvider' se carga solo
    Future.microtask(() {
      ref.read(adminControllerProvider.notifier).loadInitialData();
    });
  }

  // --- 👇 NUEVA FUNCIÓN HELPER SEGURA 👇 ---
  String _getAdminName(List<AppUser> allUsers, String establishmentId) {
    // Usamos 'firstWhereOrNull' (requiere import 'package:collection/collection.dart')
    // o un bucle 'for' para ser 100% seguros. Usemos un try-catch que es más simple.
    try {
      final admin = allUsers.firstWhere(
          (user) => user.role == 'admin' && user.establishmentId == establishmentId);
      return admin.displayName;
    } catch (e) {
      return 'Sin asignar';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Miramos los providers
    final establishmentState = ref.watch(establishmentsControllerProvider);
    final establishmentsController =
        ref.read(establishmentsControllerProvider.notifier);

    final adminState = ref.watch(adminControllerProvider);
    final List<AppUser> allUsers = adminState.users;
    
    // --- 👇 LÓGICA DE CARGA MÁS SIMPLE 👇 ---
    // Mostramos 'loading' si CUALQUIERA de los dos está cargando
    final bool isLoading =
        establishmentState.isLoading || adminState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Establecimientos Nestlé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refrescamos ambos
              ref.invalidate(establishmentsControllerProvider);
              ref.read(adminControllerProvider.notifier).loadInitialData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, establishmentsController),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: DataTable2(
                empty: Center(
                  child: Text(
                    // Mostramos el error si existe
                    establishmentState.error ?? 
                    adminState.error ??
                    'No hay establecimientos registrados.',
                  ),
                ),
                minWidth: 700,
                columns: const [
                  DataColumn2(label: Text('Nombre'), size: ColumnSize.M),
                  DataColumn2(label: Text('Dirección'), size: ColumnSize.L),
                  DataColumn2(label: Text('Tipo'), size: ColumnSize.S),
                  DataColumn2(label: Text('Administrador'), size: ColumnSize.M),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.M),
                ],
                rows: establishmentState.establishments.map((e) {
                  // --- 👇 USAMOS LA NUEVA FUNCIÓN SEGURA 👇 ---
                  final adminName = _getAdminName(allUsers, e.id);

                  return DataRow(
                    cells: [
                      DataCell(Text(e.name)),
                      DataCell(Text(e.address)),
                      DataCell(Text(e.organizationType)),
                      DataCell(Text(adminName)), // <-- Ahora es seguro
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () => _showEditDialog(
                                  context, establishmentsController, e),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar',
                              color: Colors.red,
                              onPressed: () => _confirmDelete(
                                  context, establishmentsController, e.id),
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
    );
  }

  // --- (LOS 3 DIÁLOGOS ESTÁN BIEN, NO NECESITAN CAMBIOS) ---
  Future<void> _showAddDialog(
      BuildContext context, EstablishmentsController controller) async {
    // ... tu código ...
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
              await controller.create(est);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, EstablishmentsController controller, Establishment e) async {
    // ... tu código ...
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
              await controller.update(updated);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, EstablishmentsController controller, String id) async {
    // ... tu código ...
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
      await controller.delete(id);
    }
  }
}