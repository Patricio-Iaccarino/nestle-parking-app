import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:intl/intl.dart';
import 'package:cocheras_nestle_web/features/reservations/application/reservations_controller.dart';
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/application/parking_spots_controller.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedDepartmentId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final establishmentId =
          ref.read(authControllerProvider).value?.establishmentId;

      if (establishmentId != null) {
        ref.read(reservationsControllerProvider.notifier).load(
              establishmentId,
              date: _selectedDate,
            );
        ref.read(usersControllerProvider.notifier)
            .loadUsersByEstablishment(establishmentId);
        ref.read(departmentsControllerProvider.notifier).load(establishmentId);
        ref.read(parkingSpotsControllerProvider.notifier)
            .loadByEstablishment(establishmentId);
      }
    });
  }

  void _reloadAll() {
    final establishmentId =
        ref.read(authControllerProvider).value?.establishmentId;
    if (establishmentId == null) return;

    ref
        .read(reservationsControllerProvider.notifier)
        .load(establishmentId, date: _selectedDate);
    ref.read(departmentsControllerProvider.notifier).load(establishmentId);
    ref.read(usersControllerProvider.notifier)
        .loadUsersByEstablishment(establishmentId);
    ref.read(parkingSpotsControllerProvider.notifier)
        .loadByEstablishment(establishmentId);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _reloadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservationsState = ref.watch(reservationsControllerProvider);
    final usersState = ref.watch(usersControllerProvider);
    final departmentState = ref.watch(departmentsControllerProvider);
    final spotsState = ref.watch(parkingSpotsControllerProvider);

    final isLoading = reservationsState.isLoading ||
        usersState.isLoading ||
        departmentState.isLoading ||
        spotsState.isLoading;

    final error = reservationsState.error ??
        usersState.error ??
        departmentState.error ??
        spotsState.error;

    final users = usersState.users;
    final departments = departmentState.departments;
    final allSpots = spotsState.parkingSpots;

    final filteredReleases = reservationsState.spotReleases.where((release) {
      return _selectedDepartmentId == null ||
          release.departmentId == _selectedDepartmentId;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisión de Reservas'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(160, 36),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nueva Liberación'),
              onPressed: () => _showCreateReleaseDialog(
                context: context,
                departments: departments,
                allSpots: allSpots,
                users: users,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  onPressed: _pickDate,
                ),
                const SizedBox(width: 20),
                DropdownButton<String>(
                  value: _selectedDepartmentId,
                  hint: const Text('Filtrar por Departamento'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los Departamentos'),
                    ),
                    ...departments.map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedDepartmentId = value),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reloadAll,
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : PaginatedDataTable2(
                    columns: const [
                      DataColumn2(label: Text('Cochera'), size: ColumnSize.S),
                      DataColumn2(label: Text('Depto.'), size: ColumnSize.M),
                      DataColumn2(label: Text('Estado'), size: ColumnSize.S),
                      DataColumn2(
                        label: Text('Titular (Liberó)'),
                        size: ColumnSize.L,
                      ),
                      DataColumn2(
                        label: Text('Suplente (Reservó)'),
                        size: ColumnSize.L,
                      ),
                      DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
                    ],
                    empty: Center(
                      child: Text(
                        error ??
                            'No hay reservas para la fecha y filtro seleccionados.',
                      ),
                    ),
                    rowsPerPage: 20,
                    availableRowsPerPage: const [10, 20, 50],
                    minWidth: 900,
                    showFirstLastButtons: true,
                    wrapInCard: false,
                    source: _ReservationsDataSource(
                      releases: filteredReleases,
                      allUsers: users,
                      allDepartments: departments,
                      onReserve: (releaseId, deptId) =>
                          _showReserveDialog(context, releaseId, deptId, users),
                      onCancel: (releaseId) =>
                          _confirmCancel(context, releaseId),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NUEVA LIBERACIÓN
  // ============================================================
  Future<void> _showCreateReleaseDialog({
  required BuildContext context,
  required List<Department> departments,
  required List<ParkingSpot> allSpots,
  required List<AppUser> users,
}) async {
  final establishmentId =
      ref.read(authControllerProvider).value?.establishmentId ?? '';

  if (establishmentId.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se encontró el establecimiento.')),
    );
    return;
  }

  // 🔹 Límite máximo de rango en días (inclusive)
  const int maxRangeDays = 60;

  String? departmentId;
  ParkingSpot? selectedSpot;
  AppUser? selectedTitular;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  List<ParkingSpot> spotsByDept = [];

  Future<void> pickStartDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      startDate = picked;
      // Si la fecha fin quedó antes del inicio, la ajustamos
      if (endDate.isBefore(startDate)) {
        endDate = startDate;
      }
    }
  }

  Future<void> pickEndDay() async {
    // Limitamos la fecha fin para que no supere el máximo permitido
    final DateTime maxEndForRange =
        startDate.add(Duration(days: maxRangeDays - 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: endDate.isBefore(startDate) ? startDate : endDate,
      firstDate: startDate,
      lastDate: maxEndForRange,
    );
    if (picked != null) {
      endDate = picked;
    }
  }

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          void updateListsForDept(String? dept) {
            departmentId = dept;
            selectedSpot = null;
            selectedTitular = null;

            spotsByDept = (dept == null)
                ? []
                : allSpots.where((s) => s.departmentId == dept).toList()
              ..sort((a, b) => a.spotNumber.compareTo(b.spotNumber));
          }

          void onSpotChanged(ParkingSpot? spot) {
            selectedSpot = spot;

            if (spot != null &&
                spot.assignedUserId != null &&
                spot.assignedUserId!.isNotEmpty) {
              try {
                selectedTitular =
                    users.firstWhere((u) => u.id == spot.assignedUserId);
              } catch (_) {
                selectedTitular = null;
              }
            } else {
              selectedTitular = null;
            }
          }

          return AlertDialog(
            title: const Text('Nueva Liberación'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: departmentId,
                    hint: const Text('Departamento'),
                    items: departments
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => updateListsForDept(val)),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<ParkingSpot>(
                    initialValue: selectedSpot,
                    hint: const Text('Cochera'),
                    items: spotsByDept
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                '${s.spotNumber} · Piso ${s.floor} · ${s.type}',
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => onSpotChanged(val)),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<AppUser>(
                    initialValue: selectedTitular,
                    hint: const Text('Titular que libera'),
                    items: [
                      DropdownMenuItem(
                        value: selectedTitular,
                        child: Text(
                          selectedTitular?.displayName ??
                              '(Cochera sin titular asignado)',
                        ),
                      )
                    ],
                    onChanged: null,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Desde: ${DateFormat('dd/MM/yyyy').format(startDate)}',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: const Text('Elegir'),
                        onPressed: () async {
                          await pickStartDay();
                          setState(() {});
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hasta: ${DateFormat('dd/MM/yyyy').format(endDate)}',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: const Text('Elegir'),
                        onPressed: () async {
                          await pickEndDay();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (departmentId == null || selectedSpot == null) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Completá departamento y cochera.'),
                      ),
                    );
                    return;
                  }

                  if (selectedTitular == null) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Seleccioná el titular que libera.'),
                      ),
                    );
                    return;
                  }

                  if (endDate.isBefore(startDate)) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La fecha "hasta" no puede ser anterior a la fecha "desde".',
                        ),
                      ),
                    );
                    return;
                  }

                  final rangeDays =
                      endDate.difference(startDate).inDays + 1;
                  if (rangeDays > maxRangeDays) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'El rango seleccionado es de $rangeDays días. '
                          'El máximo permitido es de $maxRangeDays días.',
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(reservationsControllerProvider.notifier)
                        .addReleaseRange(
                          establishmentId: establishmentId,
                          departmentId: departmentId!,
                          parkingSpotId: selectedSpot!.id,
                          spotNumber: selectedSpot!.spotNumber,
                          releasedByUserId: selectedTitular!.id,
                          startDate: startDate,
                          endDate: endDate,
                          reloadDate: _selectedDate,
                        );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
    },
  );
}

  // ============================================================
  // RESERVAR
  // ============================================================
  Future<void> _showReserveDialog(
    BuildContext context,
    String releaseId,
    String departmentId,
    List<AppUser> users,
  ) async {
    final establishmentId =
        ref.read(authControllerProvider).value?.establishmentId ?? '';

    if (establishmentId.isEmpty) return;

    final suplentes = users
        .where((u) => u.role == 'SUPLENTE' && u.departmentId == departmentId)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    AppUser? selectedSuplente;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reservar liberación'),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<AppUser>(
              initialValue: selectedSuplente,
              hint: const Text('Seleccionar suplente'),
              items: suplentes
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.displayName),
                      ))
                  .toList(),
              onChanged: (val) => selectedSuplente = val,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedSuplente == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seleccioná un suplente.')),
                  );
                  return;
                }

                try {
                  await ref
                      .read(reservationsControllerProvider.notifier)
                      .reserve(
                        establishmentId: establishmentId,
                        releaseId: releaseId,
                        bookedByUserId: selectedSuplente!.id,
                        dayForReload: _selectedDate,
                      );

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Reservar'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CANCELAR RESERVA
  // ============================================================
  Future<void> _confirmCancel(BuildContext context, String releaseId) async {
    final establishmentId =
        ref.read(authControllerProvider).value?.establishmentId ?? '';

    if (establishmentId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text('¿Seguro que querés cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref
            .read(reservationsControllerProvider.notifier)
            .cancel(
              establishmentId: establishmentId,
              releaseId: releaseId,
              dayForReload: _selectedDate,
            );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ReservationsDataSource extends DataTableSource {
  final List<dynamic> releases;
  final List<AppUser> allUsers;
  final List<Department> allDepartments;
  final Future<void> Function(String releaseId, String departmentId) onReserve;
  final Future<void> Function(String releaseId) onCancel;

  _ReservationsDataSource({
    required this.releases,
    required this.allUsers,
    required this.allDepartments,
    required this.onReserve,
    required this.onCancel,
  });

  String _getUserName(String? userId) {
    if (userId == null || userId.isEmpty) return '—';
    try {
      return allUsers.firstWhere((u) => u.id == userId).displayName;
    } catch (_) {
      return '—';
    }
  }

  String _getDepartmentName(String deptId) {
    try {
      return allDepartments.firstWhere((d) => d.id == deptId).name;
    } catch (_) {
      return '—';
    }
  }

  @override
  DataRow? getRow(int index) {
    if (index >= releases.length) return null;
    final r = releases[index];

    final isAvailable = r.status == 'AVAILABLE';
    final isBooked = r.status == 'BOOKED';

    return DataRow(
      cells: [
        DataCell(Text(r.spotNumber)),
        DataCell(Text(_getDepartmentName(r.departmentId))),
        DataCell(
          Chip(
            label: Text(r.status),
            backgroundColor:
                isBooked ? Colors.orange.shade100 : Colors.green.shade100,
          ),
        ),
        DataCell(Text(_getUserName(r.releasedByUserId))),
        DataCell(Text(_getUserName(r.bookedByUserId))),
        DataCell(
          Row(
            children: [
              if (isAvailable)
                IconButton(
                  tooltip: 'Reservar',
                  icon: const Icon(Icons.event_available),
                  onPressed: () => onReserve(r.id, r.departmentId),
                ),
              if (isBooked)
                IconButton(
                  tooltip: 'Cancelar reserva',
                  icon: const Icon(Icons.cancel),
                  onPressed: () => onCancel(r.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => releases.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
