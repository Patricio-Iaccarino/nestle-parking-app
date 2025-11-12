import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/application/parking_spots_controller.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para filtrar números
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:go_router/go_router.dart';

class ParkingSpotsScreen extends ConsumerStatefulWidget {
  final String departmentId;
  final String establishmentId;
  final String departmentName;

  const ParkingSpotsScreen({
    super.key,
    required this.departmentId,
    required this.establishmentId,
    required this.departmentName,
  });

  @override
  ConsumerState<ParkingSpotsScreen> createState() => _ParkingSpotsScreenState();
}

class _ParkingSpotsScreenState extends ConsumerState<ParkingSpotsScreen> {
  // --- 👇 Añadimos 'helper' para manejar el estado del diálogo de Asignar ---
  // (El de "Agregar" usará StatefulBuilder)
  final _assignDialogState = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // --- Cargamos los 3 providers necesarios ---
    Future.microtask(() {
      // 1. Carga las cocheras de este depto
      ref
          .read(parkingSpotsControllerProvider.notifier)
          .load(widget.departmentId);
      // 2. Carga los usuarios de este depto
      ref.read(adminControllerProvider.notifier).loadUsers(widget.departmentId);
      // 3. Carga los deptos (para encontrar el nombre del depto actual)
      ref
          .read(departmentsControllerProvider.notifier)
          .load(widget.establishmentId);
    });
  }

  @override
  void dispose() {
    _assignDialogState.dispose(); // Limpiamos el notifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Miramos los TRES providers ---
    final spotsState = ref.watch(parkingSpotsControllerProvider);
    final spotsController = ref.read(parkingSpotsControllerProvider.notifier);

    final adminState = ref.watch(adminControllerProvider);
    final deptsState = ref.watch(departmentsControllerProvider);
    // ------------------------------------------

    // Combinamos los estados de carga y error
    final bool isLoading =
        spotsState.isLoading || adminState.isLoading || deptsState.isLoading;
    final String? error =
        spotsState.error ?? adminState.error ?? deptsState.error;

    // Lógica para encontrar el nombre (ahora usa deptsState)
    String departmentName = 'Cocheras';
    try {
      final dept = deptsState.departments.firstWhere(
        (d) => d.id == widget.departmentId,
      );
      departmentName = 'Cocheras de ${dept.name}';
    } catch (e) {
      departmentName = widget.departmentName; // Fallback
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a Departamentos',
          onPressed: () {
            context.pop();
          },
        ),
        title: Text(departmentName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // --- 👇 ARREGLO AQUÍ 👇 ---
              ref
                  .read(parkingSpotsControllerProvider.notifier)
                  .load(widget.departmentId);
              ref
                  .read(adminControllerProvider.notifier)
                  .loadUsers(widget.departmentId);
              // Reemplaza 'invalidate' con una llamada a 'load'
              ref
                  .read(departmentsControllerProvider.notifier)
                  .load(widget.establishmentId);
              // --------------------------
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showQuickAddSpotDialog(
              context,
              spotsController,
              widget.departmentId,
              widget.establishmentId,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: PaginatedDataTable2(
                columns: const [
                  DataColumn2(label: Text('Número'), size: ColumnSize.S),
                  DataColumn2(label: Text('Piso'), size: ColumnSize.S),
                  DataColumn2(label: Text('Tipo'), size: ColumnSize.M),
                  DataColumn2(label: Text('Asignado a'), size: ColumnSize.L),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.M),
                ],
                empty: Center(
                  child: Text(error ?? 'No hay cocheras registradas.'),
                ),
                rowsPerPage: 25,
                availableRowsPerPage: const [10, 25, 50, 100],
                minWidth: 700,
                showFirstLastButtons: true,
                wrapInCard: false,
                source: _ParkingSpotsDataSource(
                  parkingSpots: spotsState.parkingSpots,
                  users: adminState.users,
                  controller: spotsController,
                  context: context,
                  dialogState:
                      _assignDialogState, // Pasa el notifier de diálogo
                  showAssignDialog: (spot, users) => _showAssignUserDialog(
                    context,
                    spotsController,
                    spot,
                    users,
                  ),
                  showDeleteDialog: (spotId) =>
                      _confirmDelete(context, spotsController, spotId),
                ),
              ),
            ),
    );
  }

  // --- DIÁLOGO ASIGNAR USUARIO ---
  Future<void> _showAssignUserDialog(
    BuildContext context,
    ParkingSpotsController controller,
    ParkingSpot spot,
    List<AppUser> allUsersInDepartment,
  ) async {
    String? selectedUserId = spot.assignedUserId;
    final assignableUsers = allUsersInDepartment
        .where((u) => u.role == 'TITULAR')
        .toList();
    List<DropdownMenuItem<String?>> dropdownItems = [];
    dropdownItems.add(
      const DropdownMenuItem<String?>(value: null, child: Text('Sin asignar')),
    );
    dropdownItems.addAll(
      assignableUsers.map(
        (u) =>
            DropdownMenuItem<String?>(value: u.id, child: Text(u.displayName)),
      ),
    );
    if (selectedUserId != null && selectedUserId.isNotEmpty) {
      bool alreadyIncluded = dropdownItems.any(
        (item) => item.value == selectedUserId,
      );
      if (!alreadyIncluded) {
        try {
          final currentlyAssignedUser = allUsersInDepartment.firstWhere(
            (u) => u.id == selectedUserId,
          );
          dropdownItems.add(
            DropdownMenuItem<String?>(
              value: currentlyAssignedUser.id,
              child: Text('${currentlyAssignedUser.displayName} (Asignado)'),
            ),
          );
        } catch (e) {
          // Usuario no encontrado
        }
      }
    }
    String? tempSelectedUserId = selectedUserId;
    _assignDialogState.value = false; // Reseteamos estado

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _assignDialogState,
        builder: (context, isSaving, child) {
          return AlertDialog(
            title: const Text('Asignar cochera a Titular'),
            content: DropdownButtonFormField<String?>(
              initialValue: tempSelectedUserId,
              items: dropdownItems,
              onChanged: isSaving
                  ? null
                  : (val) {
                      tempSelectedUserId = val;
                    },
              decoration: const InputDecoration(labelText: 'Usuario Titular'),
              selectedItemBuilder: (BuildContext context) {
                return dropdownItems.map<Widget>((
                  DropdownMenuItem<String?> item,
                ) {
                  final child = item.child;
                  if (child is Text) {
                    return Text(
                      item.value == null ? '(Sin asignar)' : child.data ?? '',
                    );
                  }
                  return const Text('');
                }).toList();
              },
            ),
            actions: [
              if (!isSaving)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        _assignDialogState.value = true;
                        final updatedSpot = spot.copyWith(
                          assignedUserId: tempSelectedUserId,
                          clearAssignedUser: tempSelectedUserId == null,
                        );

                        try {
                          await controller.update(updatedSpot);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                            _assignDialogState.value = false;
                          }
                        }
                      },
                child: Text(isSaving ? "Guardando..." : "Guardar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DIÁLOGO CONFIRMAR ELIMINAR ---
  Future<void> _confirmDelete(
    BuildContext context,
    ParkingSpotsController controller,
    String spotId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cochera'),
        content: const Text(
          '¿Estás seguro de que querés eliminar esta cochera? Esta acción no se puede deshacer.',
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
      try {
        await controller.delete(spotId, widget.departmentId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al borrar: ${e.toString()}')),
          );
        }
      }
    }
  }

  // --- 👇 DIÁLOGO AGREGAR COCHERA (ACTUALIZADO CON VALIDACIÓN) 👇 ---
  Future<void> _showQuickAddSpotDialog(
    BuildContext context,
    ParkingSpotsController controller,
    String departmentId,
    String establishmentId,
  ) async {
    // --- CAMBIO 1: Añadir FormKey y estado de carga ---
    final formKey = GlobalKey<FormState>();
    final spotNumberController = TextEditingController();
    final floorController = TextEditingController();
    String type = 'SIMPLE';
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        // --- CAMBIO 2: Añadir StatefulBuilder para el spinner ---
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Agregar Cochera Rápida'),
              // --- CAMBIO 3: Envolver en Form ---
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- CAMBIO 4: Usar TextFormField ---
                    TextFormField(
                      controller: spotNumberController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Número de Cochera',
                      ),
                      // --- CAMBIO 5: Añadir Validador ---
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El número es obligatorio';
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    TextFormField(
                      controller: floorController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Piso'),
                      keyboardType: TextInputType.number,
                      // Permite solo números
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El piso es obligatorio';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Debe ser un número';
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      items: const [
                        DropdownMenuItem(
                          value: 'SIMPLE',
                          child: Text('SIMPLE'),
                        ),
                        DropdownMenuItem(
                          value: 'TANDEM',
                          child: Text('TANDEM'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (val) => type = val ?? 'SIMPLE',
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          // --- CAMBIO 6: Validar el formulario ---
                          if (formKey.currentState?.validate() ?? false) {
                            setState(() => isSaving = true);

                            final spot = ParkingSpot(
                              id: '',
                              spotNumber: spotNumberController.text.trim(),
                              floor:
                                  int.tryParse(floorController.text.trim()) ??
                                  0,
                              type: type,
                              departmentId: departmentId,
                              assignedUserId: null,
                              assignedUserName: null,
                              establishmentId: establishmentId,
                            );

                            try {
                              await controller.create(spot);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error al crear: ${e.toString()}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(isSaving ? "Guardando..." : "Agregar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// =================================================================
// ## CLASE AUXILIAR REQUERIDA: DataTableSource
// =================================================================

class _ParkingSpotsDataSource extends DataTableSource {
  final List<ParkingSpot> parkingSpots;
  final List<AppUser> users;
  final ParkingSpotsController controller;
  final BuildContext context;
  final ValueNotifier<bool> dialogState;
  final Function(ParkingSpot, List<AppUser>) showAssignDialog;
  final Function(String) showDeleteDialog;

  _ParkingSpotsDataSource({
    required this.parkingSpots,
    required this.users,
    required this.controller,
    required this.context,
    required this.dialogState,
    required this.showAssignDialog,
    required this.showDeleteDialog,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= parkingSpots.length) {
      return null;
    }
    final spot = parkingSpots[index];

    final userName = users
        .firstWhere(
          (u) => u.id == spot.assignedUserId,
          orElse: () => AppUser.empty(), // Usamos el constructor empty
        )
        .displayName;

    return DataRow(
      cells: [
        DataCell(Text(spot.spotNumber)),
        DataCell(Text(spot.floor.toString())),
        DataCell(Text(spot.type)),
        DataCell(Text(userName)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: 'Asignar Usuario',
                onPressed: () {
                  showAssignDialog(spot, users);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: Colors.red,
                tooltip: 'Eliminar Cochera',
                onPressed: () {
                  showDeleteDialog(spot.id);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => parkingSpots.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
