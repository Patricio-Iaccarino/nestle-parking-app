import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final establishmentId = ref
          .read(authControllerProvider)
          .value
          ?.establishmentId;
      if (establishmentId != null) {
        ref
            .read(adminControllerProvider.notifier)
            .loadDashboardData(establishmentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final theme = Theme.of(context);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- Lógica de KPIs ---
    final totalSpots = state.parkingSpots.length;
    final releasesToday = state.spotReleases;
    final availableToday = releasesToday
        .where((r) => r.status == 'AVAILABLE')
        .length;
    final bookedToday = releasesToday.where((r) => r.status == 'BOOKED').length;
    final occupiedByTitulars = totalSpots - releasesToday.length;
    final totalOccupancy =
        ((bookedToday + occupiedByTitulars) / totalSpots * 100).isNaN
        ? 0
        : ((bookedToday + occupiedByTitulars) / totalSpots * 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final establishmentId = ref
                  .read(authControllerProvider)
                  .value
                  ?.establishmentId;
              if (establishmentId != null) {
                ref
                    .read(adminControllerProvider.notifier)
                    .loadDashboardData(establishmentId);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. SECCIÓN DE KPIs ---
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
                  child: _buildDepartmentSummary(context, state),
                ),
                const SizedBox(width: 24),
                // Columna derecha: Actividad Reciente
                Expanded(flex: 3, child: _buildRecentActivity(context, state)),
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

  Widget _buildDepartmentSummary(BuildContext context, AdminState state) {
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
              rows: state.departments.map((dept) {
                // Lógica para calcular métricas por depto
                final spotsInDept = state.parkingSpots.where(
                  (s) => s.departmentId == dept.id,
                );
                final releasesInDept = state.spotReleases.where(
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

// Asegúrate de que tu modelo AppUser tenga un constructor 'empty'
// En app_user_model.dart
// ...
