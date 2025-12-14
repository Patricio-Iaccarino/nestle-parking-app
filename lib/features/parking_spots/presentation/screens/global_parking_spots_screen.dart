import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/application/parking_spots_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalParkingSpotsScreen extends ConsumerStatefulWidget {
  const GlobalParkingSpotsScreen({super.key});

  @override
  ConsumerState<GlobalParkingSpotsScreen> createState() =>
      _GlobalParkingSpotsScreenState();
}

class _GlobalParkingSpotsScreenState
    extends ConsumerState<GlobalParkingSpotsScreen> {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final establishmentId =
          ref.read(authControllerProvider).value?.establishmentId;
      if (establishmentId == null) return;

      ref
          .read(parkingSpotsControllerProvider.notifier)
          .loadByEstablishment(establishmentId);
      ref
          .read(usersControllerProvider.notifier)
          .loadUsersByEstablishment(establishmentId);
      ref.read(departmentsControllerProvider.notifier).load(establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔔 Listener para mostrar errores del controller (incluye límite de cocheras)
    ref.listen<ParkingSpotsState>(
      parkingSpotsControllerProvider,
      (previous, next) {
        final err = next.error;
        if (err != null && err.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    final spotsState = ref.watch(parkingSpotsControllerProvider);
    final usersState = ref.watch(usersControllerProvider);
    final departmentsState = ref.watch(departmentsControllerProvider);

    final isLoading =
        spotsState.isLoading ||
        usersState.isLoading ||
        departmentsState.isLoading;

    final error =
        spotsState.error ?? usersState.error ?? departmentsState.error;

    final users = usersState.users;
    final departments = departmentsState.departments;

    final filteredSpots = spotsState.parkingSpots.where((s) {
      final q = searchQuery.toLowerCase();
      return s.spotNumber.toLowerCase().contains(q) ||
          s.type.toLowerCase().contains(q) ||
          (s.assignedUserName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cocheras del Establecimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final establishmentId =
                  ref.read(authControllerProvider).value?.establishmentId;
              if (establishmentId == null) return;

              ref
                  .read(parkingSpotsControllerProvider.notifier)
                  .loadByEstablishment(establishmentId);
              ref
                  .read(usersControllerProvider.notifier)
                  .loadUsersByEstablishment(establishmentId);
              ref
                  .read(departmentsControllerProvider.notifier)
                  .load(establishmentId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva Cochera',
            onPressed: () => _showCreateDialog(context, departments),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar cochera...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (q) => setState(() => searchQuery = q),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSpots.isEmpty
                    ? Center(
                        child: Text(error ?? 'No hay cocheras registradas.'),
                      )
                    : PaginatedDataTable2(
                        columns: const [
                          DataColumn2(
                              label: Text('Número'), size: ColumnSize.S),
                          DataColumn2(label: Text('Piso'), size: ColumnSize.S),
                          DataColumn2(label: Text('Tipo'), size: ColumnSize.M),
                          DataColumn2(
                            label: Text('Departamento'),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text('Asignado a'),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                              label: Text('Acciones'), size: ColumnSize.S),
                        ],
                        empty: Center(
                          child: Text(error ?? 'No se encontraron cocheras.'),
                        ),
                        rowsPerPage: 10,
                        availableRowsPerPage: const [10, 20, 50],
                        showFirstLastButtons: true,
                        wrapInCard: false,
                        source: _ParkingSpotsDataSource(
                          spots: filteredSpots,
                          users: users,
                          departments: departments,
                          onEdit: (spot) =>
                              _showEditDialog(context, spot, departments),
                          onDelete: (spotId, deptId) =>
                              _confirmDelete(context, spotId, deptId),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    List<Department> departments,
  ) async {
    final numberController = TextEditingController();
    final floorController = TextEditingController();
    String type = 'SIMPLE';
    String? selectedDepartmentId;

    final establishmentId =
        ref.read(authControllerProvider).value?.establishmentId ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Cochera'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Número'),
            ),
            TextField(
              controller: floorController,
              decoration: const InputDecoration(labelText: 'Piso'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'SIMPLE', child: Text('Simple')),
                DropdownMenuItem(value: 'TANDEM', child: Text('Tandem')),
              ],
              onChanged: (val) => type = val ?? 'SIMPLE',
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedDepartmentId,
              decoration: const InputDecoration(labelText: 'Departamento'),
              items: departments
                  .map(
                    (d) =>
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                  )
                  .toList(),
              onChanged: (val) => selectedDepartmentId = val,
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
              if (numberController.text.isEmpty ||
                  floorController.text.isEmpty ||
                  selectedDepartmentId == null) {
                return;
              }

              final spot = ParkingSpot(
                id: '',
                spotNumber: numberController.text.trim(),
                floor: int.tryParse(floorController.text) ?? 0,
                type: type,
                establishmentId: establishmentId,
                departmentId: selectedDepartmentId!,
                assignedUserId: null,
                assignedUserName: null,
              );

              await ref
                  .read(parkingSpotsControllerProvider.notifier)
                  .create(spot);

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
    ParkingSpot spot,
    List<Department> departments,
  ) async {
    final numberController = TextEditingController(text: spot.spotNumber);
    final floorController =
        TextEditingController(text: spot.floor.toString());
    String type = spot.type;

    String? selectedDepartmentId =
        spot.departmentId == "" ? null : spot.departmentId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Cochera'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Número'),
            ),
            TextField(
              controller: floorController,
              decoration: const InputDecoration(labelText: 'Piso'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'SIMPLE', child: Text('Simple')),
                DropdownMenuItem(value: 'TANDEM', child: Text('Tandem')),
              ],
              onChanged: (val) => type = val ?? 'SIMPLE',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: selectedDepartmentId,
              decoration: const InputDecoration(labelText: 'Departamento'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('- Sin departamento -'),
                ),
                ...departments.map(
                  (d) =>
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                ),
              ],
              onChanged: (val) {
                selectedDepartmentId = val;
              },
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
              final updatedSpot = ParkingSpot(
                id: spot.id,
                spotNumber: numberController.text.trim(),
                floor: int.tryParse(floorController.text) ?? 0,
                type: type,
                establishmentId: spot.establishmentId,
                departmentId: selectedDepartmentId ?? "",
                assignedUserId: spot.assignedUserId,
                assignedUserName: spot.assignedUserName,
              );

              await ref
                  .read(parkingSpotsControllerProvider.notifier)
                  .update(updatedSpot);

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
    String spotId,
    String departmentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cochera'),
        content: const Text('¿Seguro que querés eliminar esta cochera?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(parkingSpotsControllerProvider.notifier)
          .delete(spotId, departmentId);
    }
  }
}

// ---------------------------------------------------------------------------
// DATA SOURCE
// ---------------------------------------------------------------------------
class _ParkingSpotsDataSource extends DataTableSource {
  final List<ParkingSpot> spots;
  final List<AppUser> users;
  final List<Department> departments;
  final Function(ParkingSpot) onEdit;
  final Function(String, String) onDelete;

  _ParkingSpotsDataSource({
    required this.spots,
    required this.users,
    required this.departments,
    required this.onEdit,
    required this.onDelete,
  });

  String _getDepartmentName(String deptId) {
    try {
      return departments.firstWhere((d) => d.id == deptId).name;
    } catch (_) {
      return '-';
    }
  }

  String _getUserName(String? userId) {
    if (userId == null || userId.isEmpty) return '-';
    try {
      return users.firstWhere((u) => u.id == userId).displayName;
    } catch (_) {
      return '-';
    }
  }

  @override
  DataRow? getRow(int index) {
    if (index >= spots.length) return null;
    final s = spots[index];
    return DataRow(
      cells: [
        DataCell(Text(s.spotNumber)),
        DataCell(Text(s.floor.toString())),
        DataCell(Text(s.type)),
        DataCell(Text(_getDepartmentName(s.departmentId))),
        DataCell(Text(_getUserName(s.assignedUserId))),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => onEdit(s),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: Colors.red,
                onPressed: () => onDelete(s.id, s.departmentId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => spots.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
