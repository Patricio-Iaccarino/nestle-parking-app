import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:cocheras_nestle_web/features/reservations/application/reservations_controller.dart';
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/application/parking_spots_controller.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';

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
            .read(reservationsControllerProvider.notifier)
            .load(establishmentId, date: DateTime.now());
        ref
            .read(usersControllerProvider.notifier)
            .loadUsersByEstablishment(establishmentId);
        ref.read(departmentsControllerProvider.notifier).load(establishmentId);
        ref
            .read(parkingSpotsControllerProvider.notifier)
            .loadByEstablishment(establishmentId);
      }
    });
  }

  void _refreshData() {
    final establishmentId = ref
        .read(authControllerProvider)
        .value
        ?.establishmentId;
    if (establishmentId != null) {
      ref
          .read(reservationsControllerProvider.notifier)
          .load(establishmentId, date: DateTime.now());
      ref
          .read(usersControllerProvider.notifier)
          .loadUsersByEstablishment(establishmentId);
      ref.read(departmentsControllerProvider.notifier).load(establishmentId);
      ref
          .read(parkingSpotsControllerProvider.notifier)
          .loadByEstablishment(establishmentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservationsState = ref.watch(reservationsControllerProvider);
    final usersState = ref.watch(usersControllerProvider);
    final departmentState = ref.watch(departmentsControllerProvider);
    final parkingSpotsState = ref.watch(
      parkingSpotsControllerProvider,
    );
    final theme = Theme.of(context);

    final bool isLoading =
        reservationsState.isLoading ||
        usersState.isLoading ||
        departmentState.isLoading ||
        parkingSpotsState.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final parkingSpots = parkingSpotsState.parkingSpots; 
    final totalSpots = parkingSpots.length;
    final releasesToday = reservationsState.spotReleases;
    final departments = departmentState.departments;
    final users = usersState.users;
    final availableToday = releasesToday
        .where((r) => r.status == 'AVAILABLE')
        .length;
    final bookedToday = releasesToday.where((r) => r.status == 'BOOKED').length;
    final occupiedByTitulars = totalSpots - releasesToday.length;
    final totalOccupancy =
        (totalSpots == 0 || (bookedToday + occupiedByTitulars).isNaN)
        ? 0.0
        : ((bookedToday + occupiedByTitulars) / totalSpots * 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData, 
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 20,
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

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDepartmentSummary(
                    context,
                    departments,
                    parkingSpots, 
                    releasesToday,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: _buildRecentActivity(context, releasesToday, users),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildDepartmentSummary(
    BuildContext context,
    List<Department> departments,
    List<ParkingSpot> parkingSpots,
    List<SpotRelease> releasesToday,
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
              rows: departments.map((dept) {
                final spotsInDept = parkingSpots.where(
                  (s) => s.departmentId == dept.id,
                );
                final releasesInDept = releasesToday.where(
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

  Widget _buildRecentActivity(
    BuildContext context,
    List<SpotRelease> spotReleases,
    List<AppUser> users,
  ) {
    String getUserName(String? userId) {
      if (userId == null) return '';
      return users
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
            if (spotReleases.isEmpty)
              const Center(
                child: Text('No hay actividad registrada para hoy.'),
              ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: spotReleases.length > 5
                  ? 5
                  : spotReleases.length, // Limitar a 5
              itemBuilder: (context, index) {
                final release = spotReleases[index];
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
