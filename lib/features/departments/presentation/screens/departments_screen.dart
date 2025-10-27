import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      ref
          .read(adminControllerProvider.notifier)
          .loadDepartments(widget.establishmentId);
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
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.departments.isEmpty
          ? const Center(child: Text('No hay departamentos registrados.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: DataTable(
                columns: [
                  DataColumn(
                    label: Text('Nombre'),
                    headingRowAlignment: MainAxisAlignment.center,
                  ),
                  DataColumn(
                    label: Text('Descripción'),
                    headingRowAlignment: MainAxisAlignment.center,
                  ),
                  DataColumn(
                    label: Text('Acciones'),
                    headingRowAlignment: MainAxisAlignment.center,
                  ),
                ],
                rows: state.departments.map((dept) {
                  return DataRow(
                    cells: [
                      DataCell(Text(dept.name)),
                      DataCell(Text(dept.description ?? '')),
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
                                Icons.directions_car_filled_outlined,
                              ),
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
                              onPressed: () =>
                                  _showEditDialog(context, controller, dept),
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar Departamento',
                              color: Colors.red,
                              onPressed: () =>
                                  _confirmDelete(context, controller, dept.id),
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

  Future<void> _showAddDialog(
    BuildContext context,
    AdminController controller,
  ) async {
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
    BuildContext context,
    AdminController controller,
    Department dept,
  ) async {
    final nameController = TextEditingController(text: dept.name);
    final descriptionController = TextEditingController(
      text: dept.description ?? '',
    );

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
    BuildContext context,
    AdminController controller,
    String id,
  ) async {
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
