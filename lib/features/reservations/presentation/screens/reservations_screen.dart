// reservations_screen.dart
import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:intl/intl.dart';
import 'package:cocheras_nestle_web/features/reservations/application/reservations_controller.dart';
// (Importamos el users_controller que ya existe)
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';

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
    // --- 👇 CAMBIO 2: El initState ahora llama a 3 providers ---
    Future.microtask(() {
      final establishmentId = ref
          .read(authControllerProvider)
          .value
          ?.establishmentId;

      if (establishmentId != null) {
        // 1. Carga las reservaciones (NUEVO CONTROLLER)
        ref
            .read(reservationsControllerProvider.notifier)
            .load(establishmentId, date: _selectedDate);
        // 2. Carga los usuarios (USAREMOS EL USERS_CONTROLLER)
        ref
            .read(usersControllerProvider.notifier)
            .loadUsersByEstablishment(establishmentId);
        // 3. Carga los departamentos
        ref.read(departmentsControllerProvider.notifier).load(establishmentId);
      }
    });
  }

  void _loadData() {
    final establishmentId = ref
        .read(authControllerProvider)
        .value
        ?.establishmentId;
    if (establishmentId != null) {
      // --- 👇 CAMBIO 3: Llama al NUEVO controller ---
      ref
          .read(reservationsControllerProvider.notifier)
          .load(establishmentId, date: _selectedDate);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData(); // Esto ahora llama al nuevo controller
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 4: Miramos los 3 providers ---
    final reservationsState = ref.watch(reservationsControllerProvider);
    final usersState = ref.watch(usersControllerProvider);
    final departmentState = ref.watch(departmentsControllerProvider);
    // ------------------------------------------

    // Combinamos los estados
    final bool isLoading =
        reservationsState.isLoading ||
        usersState.isLoading ||
        departmentState.isLoading;
    final String? error =
        reservationsState.error ?? usersState.error ?? departmentState.error;

    // Leemos los datos de sus respectivos estados
    final users = usersState.users;
    final departments = departmentState.departments;
    final filteredReleases = reservationsState.spotReleases.where((release) {
      return _selectedDepartmentId == null ||
          release.departmentId == _selectedDepartmentId;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Supervisión de Reservas')),
      body: Column(
        children: [
          // --- BARRA DE FILTROS ---
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  onPressed: () => _selectDate(context),
                ),
                const SizedBox(width: 20),
                // Filtro por Departamento (usa 'departments' del departmentState)
                DropdownButton<String>(
                  value: _selectedDepartmentId,
                  hint: const Text('Filtrar por Departamento'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDepartmentId = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todos los Departamentos'),
                    ),
                    ...departments.map<DropdownMenuItem<String>>((
                      Department dept,
                    ) {
                      return DropdownMenuItem<String>(
                        value: dept.id,
                        child: Text(dept.name),
                      );
                    }),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  // --- 👇 CAMBIO 5: Refrescamos los 3 providers ---
                  onPressed: () {
                    final establishmentId = ref
                        .read(authControllerProvider)
                        .value
                        ?.establishmentId;
                    if (establishmentId == null) return;
                    _loadData(); // Recarga reservaciones
                    ref
                        .read(departmentsControllerProvider.notifier)
                        .load(establishmentId);
                    ref
                        .read(usersControllerProvider.notifier)
                        .loadUsersByEstablishment(establishmentId);
                  },
                ),
              ],
            ),
          ),
          // --- TABLA DE DATOS ---
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
                    ],
                    empty: Center(
                      child: Text(
                        error ??
                            'No hay reservas para la fecha y filtro seleccionados.',
                      ),
                    ),
                    rowsPerPage: 20,
                    availableRowsPerPage: const [10, 20, 50],
                    minWidth: 800,
                    showFirstLastButtons: true,
                    wrapInCard: false,
                    source: _ReservationsDataSource(
                      releases: filteredReleases,
                      allUsers: users,
                      allDepartments: departments,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReservationsDataSource extends DataTableSource {
  final List<dynamic> releases;
  final List<AppUser> allUsers;
  final List<Department> allDepartments;

  _ReservationsDataSource({
    required this.releases,
    required this.allUsers,
    required this.allDepartments,
  });

  String _getUserName(String? userId) {
    if (userId == null || userId.isEmpty) return 'N/A';
    try {
      return allUsers.firstWhere((u) => u.id == userId).displayName;
    } catch (e) {
      return 'Usuario no encontrado';
    }
  }

  String _getDepartmentName(String deptId) {
    try {
      return allDepartments.firstWhere((d) => d.id == deptId).name;
    } catch (e) {
      return 'Depto. no encontrado';
    }
  }

  @override
  DataRow? getRow(int index) {
    if (index >= releases.length) {
      return null;
    }
    final release = releases[index];

    return DataRow(
      cells: [
        DataCell(Text(release.spotNumber)),
        DataCell(Text(_getDepartmentName(release.departmentId))),
        DataCell(
          Chip(
            label: Text(release.status),
            backgroundColor: release.status == 'BOOKED'
                ? Colors.orange.shade100
                : Colors.green.shade100,
          ),
        ),
        DataCell(Text(_getUserName(release.releasedByUserId))),
        DataCell(Text(_getUserName(release.bookedByUserId))),
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
