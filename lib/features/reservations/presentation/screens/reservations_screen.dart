import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart'; // Necesitas AppUser
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart'; // Necesitas Department
import 'package:intl/intl.dart'; // Necesitarás el paquete 'intl' (flutter pub add intl)

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
      final controller = ref.read(adminControllerProvider.notifier);
      final establishmentId = ref
          .read(authControllerProvider)
          .value
          ?.establishmentId;

      if (establishmentId != null) {
        // Cargar datos necesarios para el panel
        controller.loadReservations(establishmentId, date: _selectedDate);
        // Cargar usuarios y departamentos para poder "mapear" los IDs a nombres
        controller.loadUsersForEstablishment(establishmentId);
        controller.loadDepartments(establishmentId);
      }
    });
  }

  void _loadData() {
    final establishmentId = ref
        .read(authControllerProvider)
        .value
        ?.establishmentId;
    if (establishmentId != null) {
      ref
          .read(adminControllerProvider.notifier)
          .loadReservations(establishmentId, date: _selectedDate);
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
      _loadData();
    }
  }

  // --- Funciones Helper para mapear IDs a Nombres ---
  String _getUserName(List<AppUser> users, String? userId) {
    if (userId == null || userId.isEmpty) return 'N/A';
    try {
      return users.firstWhere((u) => u.id == userId).displayName;
    } catch (e) {
      return 'Usuario no encontrado';
    }
  }

  String _getDepartmentName(List<Department> departments, String deptId) {
    try {
      return departments.firstWhere((d) => d.id == deptId).name;
    } catch (e) {
      return 'Depto. no encontrado';
    }
  }
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final users = state.users;
    final departments = state.departments;

    // Filtramos las reservas localmente si se seleccionó un departamento
    final filteredReleases = state.spotReleases.where((release) {
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
            color: Colors.grey.shade100,
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  onPressed: () => _selectDate(context),
                ),
                const SizedBox(width: 20),
                // Filtro por Departamento
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
                    }).toList(),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
          // --- TABLA DE DATOS ---
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredReleases.isEmpty
                ? const Center(
                    child: Text('No hay reservas para la fecha seleccionada.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Cochera')),
                        DataColumn(label: Text('Depto.')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Titular (Liberó)')),
                        DataColumn(label: Text('Suplente (Reservó)')),
                      ],
                      rows: filteredReleases.map((release) {
                        return DataRow(
                          cells: [
                            DataCell(Text(release.spotNumber)),
                            DataCell(
                              Text(
                                _getDepartmentName(
                                  departments,
                                  release.departmentId,
                                ),
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(release.status),
                                backgroundColor: release.status == 'BOOKED'
                                    ? Colors.orange.shade100
                                    : Colors.green.shade100,
                              ),
                            ),
                            DataCell(
                              Text(
                                _getUserName(users, release.releasedByUserId),
                              ),
                            ),
                            DataCell(
                              Text(_getUserName(users, release.bookedByUserId)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
