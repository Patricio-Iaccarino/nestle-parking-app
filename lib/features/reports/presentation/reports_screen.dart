import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/reports_controller.dart' as controller; 
import '../domain/report_models.dart';
import '../../../core/services/export_service.dart'; 
import 'package:intl/intl.dart';

/// --------------------------------------------------------------------------
/// 🔹 Pantalla principal de Reportes
/// --------------------------------------------------------------------------
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controller.reportsControllerProvider);
    final reportsController =
        ref.read(controller.reportsControllerProvider.notifier);

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: Colors.red.shade700,
        actions: [
          // 🔹 Botón Exportar
          PopupMenuButton<String>(
            tooltip: 'Exportar',
            icon: const Icon(Icons.download),
            onSelected: (value) async {
              await ExportService.export(
                format: value,
                kind: state.kind,
                daily: state.daily,
                byDepartment: state.byDepartment,
                substituteCount: state.substituteCount,
                releasesStats: state.releasesStats,
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'csv',
                child: Text('Exportar como CSV'),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Text('Exportar como PDF'),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Text('Exportar como Excel (.xlsx)'), 
              ),
            ],
          ),

          // 🔹 Botón Actualizar
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => reportsController.load(),
          ),
        ],
      ),

      // 🔹 Contenido del body
      body: Column(
        children: [
          const SizedBox(height: 8),

          // 🔹 Selector de tipo de reporte
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<ReportKind>(
              value: state.kind,
              isExpanded: true,
              onChanged: (kind) {
                if (kind != null) reportsController.setKind(kind);
              },
              items: const [
                DropdownMenuItem(
                  value: ReportKind.occupancyDaily,
                  child: Text('Ocupación diaria'),
                ),
                DropdownMenuItem(
                  value: ReportKind.byDepartment,
                  child: Text('Uso por departamento'),
                ),
                DropdownMenuItem(
                  value: ReportKind.substitutes,
                  child: Text('Reservas de suplentes'),
                ),
                DropdownMenuItem(
                  value: ReportKind.titularReleases,
                  child: Text('Liberaciones de titulares'),
                ),
              ],
            ),
          ),

          // 🔹 Selector de rango de fechas (interactivo)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () async {
                    final pickedRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: DateTimeRange(
                        start: state.filter.range.start,
                        end: state.filter.range.end,
                      ),
                      locale: const Locale('es', 'ES'),
                      builder: (context, child) {
                        // 🔹 Personalización visual (opcional)
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.red.shade700,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedRange != null) {
                      reportsController.setDateRange(pickedRange);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Desde: ${dateFormat.format(state.filter.range.start)}  '
                          'Hasta: ${dateFormat.format(state.filter.range.end)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_calendar,
                            size: 18, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // 🔹 Contenido dinámico
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : _ReportContent(state: state),
          ),
        ],
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// 🔹 Contenido dinámico del reporte según el tipo
/// --------------------------------------------------------------------------
class _ReportContent extends StatelessWidget {
  final controller.ReportsState state; 
  const _ReportContent({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Center(
        child: Text(
          '⚠️ Error: ${state.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    switch (state.kind) {
      case ReportKind.occupancyDaily:
        return _buildDailyOccupancy();
      case ReportKind.byDepartment:
        return _buildDepartmentUsage();
      case ReportKind.substitutes:
        return _buildSubstituteCount();
      case ReportKind.titularReleases:
        return _buildReleasesStats();
    }
  }

  // 📊 Reporte 1 – Ocupación diaria
  Widget _buildDailyOccupancy() {
    if (state.daily.isEmpty) {
      return const Center(child: Text('No hay datos disponibles.'));
    }

    return ListView.builder(
      itemCount: state.daily.length,
      itemBuilder: (context, index) {
        final p = state.daily[index];
        final formattedDate = DateFormat('dd/MM').format(p.day);
        return ListTile(
          leading: const Icon(Icons.calendar_today, color: Colors.red),
          title: Text('Día $formattedDate'),
          subtitle: Text(
            'Ocupadas: ${p.occupied} | Canceladas: ${p.availableForSubstitutes} | Total: ${p.reservedBySubstitutes}',
          ),
        );
      },
    );
  }

  // 🏢 Reporte 2 – Uso por departamento
  Widget _buildDepartmentUsage() {
    if (state.byDepartment.isEmpty) {
      return const Center(child: Text('No hay registros por departamento.'));
    }

    final entries = state.byDepartment.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: const Icon(Icons.apartment, color: Colors.blueGrey),
          title: Text(entry.key),
          trailing: Text('${entry.value} reservas'),
        );
      },
    );
  }

  // 👥 Reporte 3 – Reservas de suplentes
  Widget _buildSubstituteCount() {
    return Center(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 48, color: Colors.teal),
              const SizedBox(height: 12),
              const Text(
                'Reservas realizadas por suplentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '${state.substituteCount}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚗 Reporte 4 – Liberaciones de titulares
  Widget _buildReleasesStats() {
    if (state.releasesStats.isEmpty) {
      return const Center(child: Text('No hay liberaciones registradas.'));
    }

    final available = state.releasesStats['available'] ?? 0;
    final booked = state.releasesStats['booked'] ?? 0;
    final total = state.releasesStats['total'] ?? 0;

    return Center(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_parking, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'Liberaciones de titulares',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _statRow('Disponibles', available, Colors.green),
              _statRow('Reservadas', booked, Colors.blue),
              _statRow('Total', total, Colors.black87),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
