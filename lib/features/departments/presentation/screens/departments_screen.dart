import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:go_router/go_router.dart';

class DepartmentsScreen extends ConsumerStatefulWidget {
  final String establishmentId;
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
          .read(departmentsControllerProvider.notifier)
          .load(widget.establishmentId);
      ref
          .read(adminControllerProvider.notifier)
          .loadDashboardData(widget.establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final departmentState = ref.watch(departmentsControllerProvider);
    final departmentsController = ref.read(
      departmentsControllerProvider.notifier,
    );
    final adminState = ref.watch(adminControllerProvider);

    final bool isLoading = departmentState.isLoading || adminState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(departmentsControllerProvider.notifier)
                  .load(widget.establishmentId);
              ref
                  .read(adminControllerProvider.notifier)
                  .loadDashboardData(widget.establishmentId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, departmentsController),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable2(
                empty: Center(
                  child: Text(
                    departmentState.error ??
                        adminState.error ??
                        'No hay departamentos registrados.',
                  ),
                ),
                minWidth: 700,
                columnSpacing: 28,
                columns: const [
                  DataColumn2(label: Text('Nombre'), size: ColumnSize.M),
                  DataColumn2(label: Text('Descripción'), size: ColumnSize.L),
                  DataColumn2(label: Text('Cocheras'), size: ColumnSize.S),
                  DataColumn2(label: Text('Usuarios'), size: ColumnSize.S),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.L),
                ],
                rows: departmentState.departments.map((dept) {
                  final spotsInDept = adminState.parkingSpots
                      .where((s) => s.departmentId == dept.id)
                      .length;
                  final usersInDept = adminState.users
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
                                context,
                                departmentsController,
                                dept,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar Departamento',
                              color: Colors.red,
                              onPressed: () => _confirmDelete(
                                context,
                                departmentsController,
                                dept.id,
                              ),
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

  // --- 👇 CÓDIGO ACTUALIZADO CON VALIDACIÓN 👇 ---
  Future<void> _showAddDialog(
    BuildContext context,
    DepartmentsController controller,
  ) async {
    // --- CAMBIO 1: Clave del Formulario ---
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Departamento'),
        // --- CAMBIO 2: Envolver en un Form ---
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- CAMBIO 3: Cambiar a TextFormField ---
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                // --- CAMBIO 4: Añadir validador ---
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre no puede estar vacío';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                // (La descripción puede ser opcional, así que no añadimos validador)
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // --- CAMBIO 5: Validar antes de guardar ---
              if (formKey.currentState?.validate() ?? false) {
                final newDept = Department(
                  id: '',
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  establishmentId: widget.establishmentId,
                  createdAt: DateTime.now(),
                );
                await controller.create(newDept);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // --- 👇 CÓDIGO ACTUALIZADO CON VALIDACIÓN 👇 ---
  Future<void> _showEditDialog(
    BuildContext context,
    DepartmentsController controller,
    Department dept,
  ) async {
    // --- CAMBIO 1: Clave del Formulario ---
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: dept.name);
    final descriptionController =
        TextEditingController(text: dept.description ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Departamento'),
        // --- CAMBIO 2: Envolver en un Form ---
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- CAMBIO 3: Cambiar a TextFormField ---
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                // --- CAMBIO 4: Añadir validador ---
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre no puede estar vacío';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // --- CAMBIO 5: Validar antes de guardar ---
              if (formKey.currentState?.validate() ?? false) {
                final updatedDept = dept.copyWith(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                await controller.update(updatedDept);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DepartmentsController controller,
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
      await controller.delete(id, widget.establishmentId);
    }
  }
}