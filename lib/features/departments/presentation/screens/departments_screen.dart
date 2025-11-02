import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- 👇 CAMBIO 1: Importar el paquete ---
import 'package:data_table_2/data_table_2.dart';
// ------------------------------------
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:go_router/go_router.dart';

class DepartmentsScreen extends ConsumerStatefulWidget {
  final String establishmentId; // Necesario para filtrar departamentos
  const DepartmentsScreen({super.key, required this.establishmentId});

  @override
  ConsumerState<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends ConsumerState<DepartmentsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final controller = ref.read(adminControllerProvider.notifier);
      controller.loadDepartments(widget.establishmentId);
      // Traemos también usuarios y cocheras para poder contarlos
      controller.loadDashboardData(widget.establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.loadDepartments(widget.establishmentId),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, controller),
          ),
        ],
      ),
      // --- 👇 CAMBIO 2: El 'body' se simplifica ---
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16), // Mantenemos tu padding
              child: DataTable2(
                // Propiedad para cuando la lista está vacía
                empty: const Center(child: Text('No hay departamentos registrados.')),
                // Ancho mínimo (buena práctica)
                minWidth: 700, 
                // Mantenemos tu espaciado
                columnSpacing: 28,
                // Reemplazamos DataColumn por DataColumn2 y añadimos 'size'
                columns: const [
                  DataColumn2(label: Text('Nombre'), size: ColumnSize.M),
                  DataColumn2(label: Text('Descripción'), size: ColumnSize.L),
                  DataColumn2(label: Text('Cocheras'), size: ColumnSize.S),
                  DataColumn2(label: Text('Usuarios'), size: ColumnSize.S),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.L), // 'L' por los 4 botones
                ],
                // ¡Esta parte (rows) no cambia en absoluto!
                rows: state.departments.map((dept) {
                  // Contar cocheras asociadas a este departamento
                  final spotsInDept = state.parkingSpots
                      .where((s) => s.departmentId == dept.id)
                      .length;

                  // Contar usuarios asociados a este departamento
                  final usersInDept = state.users
                      .where((u) => u.departmentId == dept.id)
                      .length;

                  return DataRow(
                    cells: [
                      DataCell(Text(dept.name)),
                      DataCell(Text(dept.description ?? '')),
                      DataCell(Text(spotsInDept.toString())),
                      DataCell(Text(usersInDept.toString())),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.group),
                              tooltip: 'Gestionar Usuarios',
                              onPressed: () {
                                context.push(
                                  '/establishments/${widget.establishmentId}/departments/${dept.id}/users',
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.directions_car_filled_outlined),
                              tooltip: 'Ver Cocheras',
                              onPressed: () {
                                context.push(
                                  '/establishments/${widget.establishmentId}/departments/${dept.id}/spots',
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar Departamento',
                              onPressed: () => _showEditDialog(
                                  context, controller, dept),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar Departamento',
                              color: Colors.red,
                              onPressed: () => _confirmDelete(
                                  context, controller, dept.id),
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

  // --- (SIN CAMBIOS DESDE AQUÍ) ---
  // (Pega aquí tus 3 métodos: _showAddDialog,
  //  _showEditDialog, y _confirmDelete)

  Future<void> _showAddDialog(
      BuildContext context, AdminController controller) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Departamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
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
              final newDept = Department(
                id: '', // Se genera en el repository
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
                establishmentId: widget.establishmentId,
                createdAt: DateTime.now(),
              );
              await controller.createDepartment(newDept);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, AdminController controller, Department dept) async {
    final nameController = TextEditingController(text: dept.name);
    final descriptionController =
        TextEditingController(text: dept.description ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Departamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
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
              final updatedDept = dept.copyWith(
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
              );
              await controller.updateDepartment(updatedDept);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AdminController controller, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar departamento'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este departamento? Esta acción no se puede deshacer.',
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
      await controller.deleteDepartments(id);
    }
  }
}