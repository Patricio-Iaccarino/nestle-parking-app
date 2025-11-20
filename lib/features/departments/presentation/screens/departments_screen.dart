import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:go_router/go_router.dart';
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/application/parking_spots_controller.dart';
import 'package:cocheras_nestle_web/features/establishments/application/establishments_controller.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';

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
          .read(usersControllerProvider.notifier)
          .loadUsersByEstablishment(widget.establishmentId);
      ref
          .read(parkingSpotsControllerProvider.notifier)
          .loadByEstablishment(widget.establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final departmentState = ref.watch(departmentsControllerProvider);
    final departmentsController = ref.read(
      departmentsControllerProvider.notifier,
    );
    final usersState = ref.watch(usersControllerProvider);
    final parkingSpotsState = ref.watch(parkingSpotsControllerProvider);
    final establishmentsController = ref.read(
      establishmentsControllerProvider.notifier,
    );
    final Establishment? currentEstablishment = establishmentsController
        .getEstablishmentById(widget.establishmentId);

    if (currentEstablishment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // -------------------------------------

    final bool isLoading =
        departmentState.isLoading ||
        usersState.isLoading ||
        parkingSpotsState.isLoading;

    final String? error =
        departmentState.error ?? usersState.error ?? parkingSpotsState.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // --- 👇 CAMBIO 4: Refrescamos los TRES ---
            onPressed: () {
              ref
                  .read(departmentsControllerProvider.notifier)
                  .load(widget.establishmentId);
              ref
                  .read(usersControllerProvider.notifier)
                  .loadUsersByEstablishment(widget.establishmentId);
              ref
                  .read(parkingSpotsControllerProvider.notifier)
                  .loadByEstablishment(widget.establishmentId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddDialog(
                context,
                departmentsController,
                currentEstablishment,
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable2(
                empty: Center(
                  child: Text(error ?? 'No hay departamentos registrados.'),
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
                  final spotsInDept = parkingSpotsState.parkingSpots
                      .where((s) => s.departmentId == dept.id)
                      .length;

                  final usersInDept = usersState.users
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
                                  // (Esta ruta funciona gracias a la lógica del AppLayout que arreglamos)
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
                                  '/establishments/${widget.establishmentId}/departments/${dept.id}/spots?departmentName=${Uri.encodeComponent(dept.name)}',
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar Departamento',
                              onPressed: () {
                                _showEditDialog(
                                  context,
                                  departmentsController,
                                  dept,
                                  currentEstablishment,
                                );
                              },
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

  
  Future<void> _showAddDialog(
    BuildContext context,
    DepartmentsController controller,
    Establishment currentEstablishment,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final parkingSpotsController = TextEditingController();

    final departmentState = ref.read(departmentsControllerProvider);
    final totalAssignedSpots = departmentState.departments.fold<int>(
      0,
      (sum, dept) => sum + dept.parkingSpotsCount,
    );
    final availableSpots =
        currentEstablishment.totalParkingSpots - totalAssignedSpots;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Departamento'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
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
              TextFormField(
                controller: parkingSpotsController,
                decoration: InputDecoration(
                  labelText: 'Cantidad de Cocheras',
                  helperText: 'Disponibles: $availableSpots',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obligatorio';
                  }
                  final spots = int.tryParse(value);
                  if (spots == null || spots < 0) {
                    return 'Ingrese un número válido';
                  }
                  if (spots > availableSpots) {
                    return 'Excede las cocheras disponibles ($availableSpots)';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
              if (formKey.currentState?.validate() ?? false) {
                final newDept = Department(
                  id: '',
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  establishmentId: widget.establishmentId,
                  createdAt: DateTime.now(),
                  parkingSpotsCount: int.parse(parkingSpotsController.text),
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

  Future<void> _showEditDialog(
    BuildContext context,
    DepartmentsController controller,
    Department dept,
    Establishment currentEstablishment,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: dept.name);
    final descriptionController = TextEditingController(
      text: dept.description ?? '',
    );
    final parkingSpotsController = TextEditingController(
      text: dept.parkingSpotsCount.toString(),
    );

    final departmentState = ref.read(departmentsControllerProvider);
    final totalAssignedSpots = departmentState.departments.fold<int>(
      0,
      (sum, d) => sum + d.parkingSpotsCount,
    );
    final availableSpots =
        currentEstablishment.totalParkingSpots -
        totalAssignedSpots +
        dept.parkingSpotsCount;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Departamento'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
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
              TextFormField(
                controller: parkingSpotsController,
                decoration: InputDecoration(
                  labelText: 'Cantidad de Cocheras',
                  helperText: 'Disponibles: $availableSpots',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obligatorio';
                  }
                  final spots = int.tryParse(value);
                  if (spots == null || spots < 0) {
                    return 'Ingrese un número válido';
                  }
                  if (spots > availableSpots) {
                    return 'Excede las cocheras disponibles ($availableSpots)';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
              if (formKey.currentState?.validate() ?? false) {
                final updatedDept = dept.copyWith(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  parkingSpotsCount: int.parse(parkingSpotsController.text),
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
