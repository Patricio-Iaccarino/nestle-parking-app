import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // --- 👇 CAMBIO 2: El initState ahora llama a AMBOS controllers ---
    Future.microtask(() {
      final establishmentId = ref
          .read(authControllerProvider)
          .value
          ?.establishmentId;
      if (establishmentId != null) {
        // 1. Llama al provider de admin (carga users, spots, releases)
        ref
            .read(adminControllerProvider.notifier)
            .loadDashboardData(establishmentId);
        // 2. Llama al nuevo provider de departamentos
        ref.read(departmentsControllerProvider.notifier).load(establishmentId);
      }
    });
  }

  void _refreshData() {
    final establishmentId = ref
        .read(authControllerProvider)
        .value
        ?.establishmentId;
    if (establishmentId != null) {
      // --- 👇 CAMBIO 3: El refresh también llama a AMBOS ---
      ref
          .read(adminControllerProvider.notifier)
          .loadDashboardData(establishmentId);
      ref.read(departmentsControllerProvider.notifier).load(establishmentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 4: Miramos AMBOS providers ---
    final adminState = ref.watch(adminControllerProvider);
    final departmentState = ref.watch(departmentsControllerProvider);
    final theme = Theme.of(context);

    // El estado de carga depende de AMBOS
    final bool isLoading = adminState.isLoading || departmentState.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Mostramos error si CUALQUIERA de los dos falla
    if (adminState.error != null || departmentState.error != null) {
      return Center(
        child: Text(
          'Error al cargar: ${adminState.error ?? departmentState.error}',
        ),
      );
    }

    // --- Lógica de KPIs (usa solo adminState, está bien) ---
    final totalSpots = adminState.parkingSpots.length;
    final releasesToday = adminState.spotReleases;
    final availableToday = releasesToday
        .where((r) => r.status == 'AVAILABLE')
        .length;
    final bookedToday = releasesToday.where((r) => r.status == 'BOOKED').length;
    final occupiedByTitulars = totalSpots - releasesToday.length;
    final totalOccupancy =
        (totalSpots == 0 ||
            (bookedToday + occupiedByTitulars)
                .isNaN) // Evitar división por cero
        ? 0.0
        : ((bookedToday + occupiedByTitulars) / totalSpots * 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData, // Llama a la función de refresco
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. SECCIÓN DE KPIs (Sin cambios) ---
            Wrap(
              spacing: 20, // Espacio horizontal
              runSpacing: 20, // Espacio vertical
              children: [
                _buildKpiCard(
                  context,
                  icon: Icons.directions_car,
                  title: 'Ocupación Total (Hoy)',
                  value: '${totalOccupancy.toStringAsFixed(0)}%',
                  color: theme.colorScheme.primary,
                ),
                _buildKpiCard(
                  context,
                  icon: Icons.event_available,
                  title: 'Disponibles (Suplentes)',
                  value: availableToday.toString(),
                  color: Colors.green.shade600,
                ),
                _buildKpiCard(
                  context,
                  icon: Icons.event_busy,
                  title: 'Reservados (Suplentes)',
                  value: bookedToday.toString(),
                  color: Colors.orange.shade700,
                ),
                _buildKpiCard(
                  context,
                  icon: Icons.numbers,
                  title: 'Total Cocheras',
                  value: totalSpots.toString(),
                  color: Colors.grey.shade600,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- 2. SECCIÓN DE RESUMEN POR DEPTO Y ACTIVIDAD ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: Resumen por Depto
                Expanded(
                  flex: 2,
                  // --- 👇 CAMBIO 5: Pasamos los datos correctos ---
                  child: _buildDepartmentSummary(
                    context,
                    departmentState.departments, // La lista de deptos
                    adminState, // El resto de los datos (spots, releases)
                  ),
                ),
                const SizedBox(width: 24),
                // Columna derecha: Actividad Reciente (Sin cambios)
                Expanded(
                  flex: 3,
                  child: _buildRecentActivity(context, adminState),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS COMPONENTES ---

  Widget _buildKpiCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    // ... (Este widget no tiene cambios)
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 👇 CAMBIO 6: Actualizamos la firma del widget ---
  Widget _buildDepartmentSummary(
    BuildContext context,
    List<Department> departments, // Recibe la lista de deptos
    AdminState adminState, // Recibe el resto del estado
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ocupación por Departamento (Hoy)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DataTable(
              columns: const [
                DataColumn(label: Text('Departamento')),
                DataColumn(label: Text('Ocupadas')),
                DataColumn(label: Text('Disponibles')),
              ],
              // Usamos la lista de 'departments' del parámetro
              rows: departments.map((dept) {
                // La lógica de cálculo usa 'adminState'
                final spotsInDept = adminState.parkingSpots.where(
                  (s) => s.departmentId == dept.id,
                );
                final releasesInDept = adminState.spotReleases.where(
                  (r) => r.departmentId == dept.id,
                );
                final bookedInDept = releasesInDept
                    .where((r) => r.status == 'BOOKED')
                    .length;
                final availableInDept = releasesInDept
                    .where((r) => r.status == 'AVAILABLE')
                    .length;
                final titularInDept =
                    spotsInDept.length - releasesInDept.length;
                final occupied = titularInDept + bookedInDept;

                return DataRow(
                  cells: [
                    DataCell(Text(dept.name)),
                    DataCell(Text('$occupied / ${spotsInDept.length}')),
                    DataCell(Text(availableInDept.toString())),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Este widget solo depende de 'adminState', así que está bien
  Widget _buildRecentActivity(BuildContext context, AdminState state) {
    String getUserName(String? userId) {
      if (userId == null) return '';
      return state.users
          .firstWhere((u) => u.id == userId, orElse: () => AppUser.empty())
          .displayName;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad Reciente (Hoy)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (state.spotReleases.isEmpty)
              const Center(
                child: Text('No hay actividad registrada para hoy.'),
              ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: state.spotReleases.length > 5
                  ? 5
                  : state.spotReleases.length, // Limitar a 5
              itemBuilder: (context, index) {
                final release = state.spotReleases[index];
                final isBooked = release.status == 'BOOKED';
                return ListTile(
                  leading: Icon(
                    isBooked ? Icons.check_circle : Icons.info_outline,
                    color: isBooked
                        ? Colors.orange.shade700
                        : Colors.green.shade600,
                  ),
                  title: Text(
                    isBooked
                        ? 'Cochera ${release.spotNumber} reservada'
                        : 'Cochera ${release.spotNumber} liberada',
                  ),
                  subtitle: Text(
                    isBooked
                        ? 'Por: ${getUserName(release.bookedByUserId)}'
                        : 'Por: ${getUserName(release.releasedByUserId)}',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
