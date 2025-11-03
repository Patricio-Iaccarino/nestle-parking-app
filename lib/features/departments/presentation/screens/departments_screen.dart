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
    // --- 👇 CAMBIO 2: El initState ahora llama a AMBOS controllers ---
    Future.microtask(() {
      // 1. Llama al nuevo controller para cargar los departamentos
      ref
          .read(departmentsControllerProvider.notifier)
          .load(widget.establishmentId);

      // 2. Llama al viejo controller para cargar spots y users
      //    (Esto asume que arreglaste 'loadDashboardData' como te indiqué)
      ref
          .read(adminControllerProvider.notifier)
          .loadDashboardData(widget.establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 3: Miramos AMBOS providers ---
    // 1. El nuevo provider para la lista de departamentos
    final departmentState = ref.watch(departmentsControllerProvider);
    final departmentsController = ref.read(
      departmentsControllerProvider.notifier,
    );

    // 2. El provider antiguo, para 'users' y 'parkingSpots'
    final adminState = ref.watch(adminControllerProvider);
    // -------------------------------------

    // El estado de carga depende de AMBOS
    final bool isLoading = departmentState.isLoading || adminState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // --- 👇 CAMBIO 4: Refrescamos AMBOS ---
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
            // Pasamos el NUEVO controller al diálogo
            onPressed: () => _showAddDialog(context, departmentsController),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable2(
                // --- 👇 CAMBIO 5: Usamos el nuevo estado ---
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
                // Usamos la lista de departamentos del NUEVO estado
                rows: departmentState.departments.map((dept) {
                  // Seguimos usando 'parkingSpots' y 'users' del VIEJO estado
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
                              // Pasamos el NUEVO controller
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
                              // Pasamos el NUEVO controller
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

  // --- 👇 CAMBIO 6: Actualizamos la firma de los diálogos ---

  Future<void> _showAddDialog(
    BuildContext context,
    DepartmentsController controller,
  ) async {
    // <-- TIPO CAMBIADO
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
                establishmentId:
                    widget.establishmentId, // <-- Lo toma del widget
                createdAt: DateTime.now(),
              );
              // --- 👇 LLAMAMOS AL NUEVO MÉTODO ---
              await controller.create(newDept);
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
    DepartmentsController controller,
    Department dept,
  ) async {
    // <-- TIPO CAMBIADO
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
              // --- 👇 LLAMAMOS AL NUEVO MÉTODO ---
              await controller.update(updatedDept);
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
    DepartmentsController controller,
    String id,
  ) async {
    // <-- TIPO CAMBIADO
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
      // --- 👇 LLAMAMOS AL NUEVO MÉTODO ---
      // Le pasamos el 'establishmentId' para que sepa qué lista recargar
      await controller.delete(id, widget.establishmentId);
    }
  }
}
