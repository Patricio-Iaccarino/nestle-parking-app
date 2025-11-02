// --- 👇 CAMBIO 1: Importar el paquete ---
import 'package:data_table_2/data_table_2.dart';
// ------------------------------------
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final controller = ref.read(adminControllerProvider.notifier);
      controller.loadParkingSpots(widget.departmentId);
      controller.loadUsers(widget.departmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);
    final parkingSpots = state.parkingSpots;
    final users = state.users;
    String departmentName = 'Cocheras';
    try {
      final dept = state.departments.firstWhere(
        (d) => d.id == widget.departmentId,
      );
      departmentName = 'Cocheras de ${dept.name}';
    } catch (e) {
      departmentName = widget.departmentName;
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
            onPressed: () => controller.loadParkingSpots(widget.departmentId),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showQuickAddSpotDialog(
              context,
              controller,
              widget.departmentId,
              widget.establishmentId,
            ),
          ),
        ],
      ),
      // --- 👇 CAMBIO 2: El 'body' se reemplaza ---
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: PaginatedDataTable2(
                // Columnas con DataColumn2 y 'size'
                columns: const [
                  DataColumn2(label: Text('Número'), size: ColumnSize.S),
                  DataColumn2(label: Text('Piso'), size: ColumnSize.S),
                  DataColumn2(label: Text('Tipo'), size: ColumnSize.M),
                  DataColumn2(label: Text('Asignado a'), size: ColumnSize.L),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.M),
                ],
                // Mensaje si la lista está vacía
                empty: const Center(child: Text('No hay cocheras registradas.')),
                
                // Configuración de paginación
                rowsPerPage: 25, // Cuántas mostrar por página
                availableRowsPerPage: const [10, 25, 50, 100], // Opciones para el usuario
                
                // Ancho mínimo y botones
                minWidth: 700,
                showFirstLastButtons: true,
                wrapInCard: false, // Sin Card exterior

                // La clase 'source' que maneja la lógica de datos
                source: _ParkingSpotsDataSource(
                  parkingSpots: parkingSpots,
                  users: users,
                  controller: controller,
                  context: context,
                  // Pasamos las funciones de los diálogos
                  showAssignDialog: (spot, users) =>
                      _showAssignUserDialog(context, controller, spot, users),
                  showDeleteDialog: (spotId) =>
                      _confirmDelete(context, controller, spotId),
                ),
              ),
            ),
    );
  }

  // --- (SIN CAMBIOS DESDE AQUÍ) ---
  // Todos tus métodos de diálogo (_showAssignUserDialog, _confirmDelete, 
  // y _showQuickAddSpotDialog) van aquí, sin cambios.

  Future<void> _showAssignUserDialog(
    BuildContext context,
    AdminController controller, // Cambiado de 'dynamic' a 'AdminController'
    ParkingSpot spot,
    List<AppUser> allUsersInDepartment, // Recibe la lista completa del depto
  ) async {
    String? selectedUserId = spot.assignedUserId; // El ID del usuario actualmente asignado

    // Usuarios que PUEDEN ser asignados (solo Titulares del depto)
    final assignableUsers = allUsersInDepartment
        .where((u) => u.role == 'TITULAR')
        .toList();

    // Construye la lista de opciones (items) para el Dropdown
    List<DropdownMenuItem<String?>> dropdownItems = [];

    // Opción "Sin asignar"
    dropdownItems.add(const DropdownMenuItem<String?>(
      value: null, // Usamos null para "sin asignar"
      child: Text('Sin asignar'),
    ));

    // Añade los usuarios titulares asignables
    dropdownItems.addAll(
      assignableUsers.map(
        (u) => DropdownMenuItem<String?>(
          value: u.id,
          child: Text(u.displayName),
        ),
      ),
    );

    // Asegúrate de que el usuario *actualmente asignado* esté en la lista,
    // incluso si ya no es 'TITULAR' (para evitar el error).
    if (selectedUserId != null && selectedUserId.isNotEmpty) {
      bool alreadyIncluded = dropdownItems.any((item) => item.value == selectedUserId);
      if (!alreadyIncluded) {
        try {
          // Búscalo en la lista completa del departamento
          final currentlyAssignedUser = allUsersInDepartment.firstWhere((u) => u.id == selectedUserId);
          dropdownItems.add(DropdownMenuItem<String?>(
            value: currentlyAssignedUser.id,
            // Añadimos una indicación visual
            child: Text('${currentlyAssignedUser.displayName} (Asignado)'),
          ));
        } catch (e) {
          // El usuario asignado ya no existe en la lista del departamento.
        }
      }
    }

    // Variable temporal para manejar el cambio dentro del diálogo
    String? tempSelectedUserId = selectedUserId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar cochera a Titular'),
        content: DropdownButtonFormField<String?>(
          initialValue: tempSelectedUserId, // Usa la variable temporal
          items: dropdownItems,
          onChanged: (val) {
            // Actualiza la variable temporal cuando el usuario elige algo
            tempSelectedUserId = val;
          },
          decoration: const InputDecoration(labelText: 'Usuario Titular'),
          selectedItemBuilder: (BuildContext context) {
            // Muestra el texto correcto cuando una opción está seleccionada
            return dropdownItems.map<Widget>((DropdownMenuItem<String?> item) {
              final child = item.child;
              if (child is Text) {
                // Muestra '(Sin asignar)' si el valor es null
                return Text(item.value == null ? '(Sin asignar)' : child.data ?? '');
              }
              return const Text(''); // Fallback
            }).toList();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Usa el valor final de la variable temporal al guardar
              final updatedSpot = spot.copyWith(
                assignedUserId: tempSelectedUserId,
                clearAssignedUser: tempSelectedUserId == null,
              );
              await controller.updateParkingSpot(updatedSpot);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller, // Cambiado de 'dynamic' a 'AdminController'
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
      await controller.deleteParkingSpot(spotId);
    }
  }

  Future<void> _showQuickAddSpotDialog(
    BuildContext context,
    AdminController controller,
    String departmentId,
    String establishmentId,
  ) async {
    final spotNumberController = TextEditingController();
    final floorController = TextEditingController();
    String type = 'SIMPLE';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Cochera Rápida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: spotNumberController,
              decoration: const InputDecoration(labelText: 'Número de Cochera'),
            ),
            TextField(
              controller: floorController,
              decoration: const InputDecoration(labelText: 'Piso'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'SIMPLE', child: Text('SIMPLE')),
                DropdownMenuItem(value: 'TANDEM', child: Text('TANDEM')),
              ],
              onChanged: (val) => type = val ?? 'SIMPLE',
              decoration: const InputDecoration(labelText: 'Tipo'),
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
              final spot = ParkingSpot(
                id: '',
                spotNumber: spotNumberController.text.trim(),
                floor: int.tryParse(floorController.text.trim()) ?? 0,
                type: type,
                departmentId: departmentId,
                assignedUserId: null,
                assignedUserName: null,
                establishmentId: establishmentId,
              );
              await controller.createParkingSpot(spot);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
} // Fin de _ParkingSpotsScreenState


// =================================================================
// ## CLASE AUXILIAR REQUERIDA: DataTableSource
// =================================================================

class _ParkingSpotsDataSource extends DataTableSource {
  final List<ParkingSpot> parkingSpots;
  final List<AppUser> users; // Usuarios del departamento
  final AdminController controller;
  final BuildContext context;
  // Funciones callback para los diálogos
  final Function(ParkingSpot, List<AppUser>) showAssignDialog;
  final Function(String) showDeleteDialog;

  _ParkingSpotsDataSource({
    required this.parkingSpots,
    required this.users,
    required this.controller,
    required this.context,
    required this.showAssignDialog,
    required this.showDeleteDialog,
  });

  // 1. Construye UNA fila
  @override
  DataRow? getRow(int index) {
    if (index >= parkingSpots.length) {
      return null;
    }
    final spot = parkingSpots[index];

    // Lógica para buscar el nombre (la misma que tenías)
    final userName = users
        .firstWhere(
          (u) => u.id == spot.assignedUserId,
          orElse: () => AppUser(
              id: '', displayName: 'Sin asignar', /*...otros defaults...*/
              email: '', role: '', establishmentId: '', establishmentName: '',
              departmentId: '', vehiclePlates: []
          ),
        )
        .displayName;

    // Devuelve la misma DataRow que ya tenías
    return DataRow(cells: [
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
    ]);
  }

  // 2. Le dice a la tabla cuántas filas hay en total
  @override
  int get rowCount => parkingSpots.length;

  // 3. Le dice si la data cambió (siempre true para simplificar)
  @override
  bool get isRowCountApproximate => false;

  // 4. Le dice cuál es la fila seleccionada (ninguna)
  @override
  int get selectedRowCount => 0;
}