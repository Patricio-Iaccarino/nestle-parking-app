import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:go_router/go_router.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart'; // NEW
import 'package:cocheras_nestle_web/features/establishments/application/establishments_controller.dart'; // NEW

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

    // --- 👇 CAMBIO 3.1: Encontrar el establecimiento actual ---
    final establishmentState = ref.watch(establishmentsControllerProvider);
    final currentEstablishment = establishmentState.establishments.firstWhere(
      (e) => e.id == widget.establishmentId,
      // Fallback por si no se encuentra, aunque no debería pasar
      orElse: () => Establishment(
        id: widget.establishmentId,
        name: 'Desconocido',
        address: '',
        organizationType: '',
        totalParkingSpots: 0,
        createdAt: DateTime.now(),
      ),
    );
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
            // --- 👇 CAMBIO 6.1: Pasamos el establecimiento actual ---
            onPressed: () => _showAddDialog(
              context,
              departmentsController,
              currentEstablishment, // <-- Pasamos el objeto
            ),
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
                                currentEstablishment, // <-- Pasamos el objeto
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

  // --- 👇 CAMBIO 6.2: Actualizamos la firma y la lógica del diálogo ---
  Future<void> _showAddDialog(
    BuildContext context,
    DepartmentsController controller,
    Establishment establishment, // <-- Recibe el objeto Establishment
  ) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final numberOfSpotsController = TextEditingController();

    // --- LÓGICA DE VALIDACIÓN (AHORA MÁS SIMPLE) ---
    final departmentState = ref.read(departmentsControllerProvider);
    final totalCapacity = establishment.totalParkingSpots;
    final allocatedSpots = departmentState.departments
        .fold<int>(0, (prev, dept) => prev + dept.numberOfSpots);
    final availableSpots = totalCapacity - allocatedSpots;
    // -----------------------------------------

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Departamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cocheras disponibles: $availableSpots',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: numberOfSpotsController,
              decoration:
                  const InputDecoration(labelText: 'Cantidad de Cocheras'),
              keyboardType: TextInputType.number,
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
              final newSpots =
                  int.tryParse(numberOfSpotsController.text.trim()) ?? 0;

              if (newSpots > availableSpots) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error de validación'),
                    content: Text(
                        'El número de cocheras ($newSpots) excede las disponibles ($availableSpots).'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                return;
              }

              final newDept = Department(
                id: '',
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
                numberOfSpots: newSpots,
                establishmentId: widget.establishmentId,
                createdAt: DateTime.now(),
              );
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
    Establishment establishment, // <-- Recibe el objeto Establishment
  ) async {
    final nameController = TextEditingController(text: dept.name);
    final descriptionController = TextEditingController(
      text: dept.description ?? '',
    );
    final numberOfSpotsController =
        TextEditingController(text: dept.numberOfSpots.toString());

    // --- LÓGICA DE VALIDACIÓN (AHORA MÁS SIMPLE) ---
    final departmentState = ref.read(departmentsControllerProvider);
    final totalCapacity = establishment.totalParkingSpots;
    // Suma las cocheras de OTROS departamentos
    final allocatedToOthers = departmentState.departments
        .where((d) => d.id != dept.id)
        .fold<int>(0, (prev, d) => prev + d.numberOfSpots);
    final availableSpots = totalCapacity - allocatedToOthers;
    // -----------------------------------------

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Departamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cocheras disponibles: $availableSpots',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: numberOfSpotsController,
              decoration:
                  const InputDecoration(labelText: 'Cantidad de Cocheras'),
              keyboardType: TextInputType.number,
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
              final newSpots =
                  int.tryParse(numberOfSpotsController.text.trim()) ?? 0;

              if (newSpots > availableSpots) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error de validación'),
                    content: Text(
                        'El número de cocheras ($newSpots) excede las disponibles ($availableSpots).'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                return;
              }

              final updatedDept = dept.copyWith(
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
                numberOfSpots: newSpots,
              );
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
