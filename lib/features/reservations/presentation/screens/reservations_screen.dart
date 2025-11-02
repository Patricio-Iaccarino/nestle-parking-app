import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- 👇 CAMBIO 1: Importar el paquete ---
import 'package:data_table_2/data_table_2.dart';
// ------------------------------------
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart'; 
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart'; 
import 'package:intl/intl.dart';

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

  // --- (Las funciones Helper _getUserName y _getDepartmentName
  //      se moverán a la clase _ReservationsDataSource) ---

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
          // --- BARRA DE FILTROS (SIN CAMBIOS) ---
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
                    }),
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
          // --- TABLA DE DATOS (CON CAMBIOS) ---
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                // --- 👇 CAMBIO 2: Reemplazamos SingleChildScrollView/DataTable ---
                : PaginatedDataTable2(
                    columns: const [
                      DataColumn2(label: Text('Cochera'), size: ColumnSize.S),
                      DataColumn2(label: Text('Depto.'), size: ColumnSize.M),
                      DataColumn2(label: Text('Estado'), size: ColumnSize.S),
                      DataColumn2(label: Text('Titular (Liberó)'), size: ColumnSize.L),
                      DataColumn2(label: Text('Suplente (Reservó)'), size: ColumnSize.L),
                    ],
                    // Mensaje si la lista filtrada está vacía
                    empty: const Center(
                      child: Text('No hay reservas para la fecha y filtro seleccionados.'),
                    ),
                    // Configuración de paginación
                    rowsPerPage: 20, // O el número que prefieras
                    availableRowsPerPage: const [10, 20, 50],
                    // Ancho mínimo y botones
                    minWidth: 800,
                    showFirstLastButtons: true,
                    wrapInCard: false,
                    // La clase 'source' que maneja la lógica de datos
                    source: _ReservationsDataSource(
                      releases: filteredReleases, // Le pasamos la lista filtrada
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

// =================================================================
// ## CLASE AUXILIAR REQUERIDA: DataTableSource
// =================================================================

class _ReservationsDataSource extends DataTableSource {
  final List<dynamic> releases; // Tu modelo SpotRelease
  final List<AppUser> allUsers;
  final List<Department> allDepartments;

  _ReservationsDataSource({
    required this.releases,
    required this.allUsers,
    required this.allDepartments,
  });

  // --- Funciones Helper (movidas aquí) ---
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
  // -----------------------------------------

  // 1. Construye UNA fila
  @override
  DataRow? getRow(int index) {
    if (index >= releases.length) {
      return null;
    }
    final release = releases[index];

    return DataRow(
      cells: [
        DataCell(Text(release.spotNumber)),
        DataCell(
          Text(
            _getDepartmentName(release.departmentId),
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
            _getUserName(release.releasedByUserId),
          ),
        ),
        DataCell(
          Text(_getUserName(release.bookedByUserId)),
        ),
      ],
    );
  }

  // 2. Le dice a la tabla cuántas filas hay en total (después de filtrar)
  @override
  int get rowCount => releases.length;

  // 3. Le dice si la data cambió (siempre true para simplificar)
  @override
  bool get isRowCountApproximate => false;

  // 4. Le dice cuál es la fila seleccionada (ninguna)
  @override
  int get selectedRowCount => 0;
}