import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../application/reports_controller.dart';
import '../../domain/report_models.dart';
import '../../../../core/services/export_service.dart';


/// SCREEN PRINCIPAL
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _searchText = "";

  @override
Widget build(BuildContext context) {
  final state = ref.watch(reportsControllerProvider);
  final controller = ref.read(reportsControllerProvider.notifier);

  // Filtro de texto libre sobre los registros detallados
  final filtered = state.detailed.where((e) {
    final s = _searchText.toLowerCase();
    if (s.isEmpty) return true;

    return (e.userName ?? "").toLowerCase().contains(s) ||
        (e.departmentName ?? "").toLowerCase().contains(s) ||
        (e.spotName ?? "").toLowerCase().contains(s) ||
        (e.spotType ?? "").toLowerCase().contains(s);
  }).toList();

  return Scaffold(
    appBar: AppBar(
      title: const Text("Reporte de Ocupación de Cocheras"),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: "Actualizar",
          onPressed: controller.loadReport,
        ),
        PopupMenuButton<String>(
          tooltip: "Exportar",
          icon: const Icon(Icons.download),
          onSelected: (f) => ExportService.exportDetailed(f, filtered),
          itemBuilder: (_) => const [
            PopupMenuItem(value: "excel", child: Text("Exportar Excel")),
            PopupMenuItem(value: "csv", child: Text("Exportar CSV")),
            PopupMenuItem(value: "pdf", child: Text("Exportar PDF")),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        const SizedBox(height: 6),

        // Selector de rango de fechas
        _DateRangePicker(state: state, controller: controller),

        // Buscador + filtro de departamentos
        _FiltersRow(
          onSearch: (t) => setState(() => _searchText = t),
          onDeptSelected: controller.setDeptFilter,
        ),

        // KPIs
        _KpiRow(),

        // Totales basados en los registros filtrados
        _TotalsRow(records: filtered),

        const Divider(height: 1),

        // Contenido principal: loader / error / tabla paginada
        Expanded(
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                  ? Center(
                      child: Text(
                        "⚠️ ${state.error}",
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            "No hay registros para el filtro seleccionado.",
                          ),
                        )
                      : PaginatedDataTable2(
                          columns: const [
                            DataColumn2(
                              label: Text("Fecha"),
                              size: ColumnSize.M,
                            ),
                            DataColumn2(
                              label: Text("Estado"),
                              size: ColumnSize.S,
                            ),
                            DataColumn2(
                              label: Text("Usuario"),
                              size: ColumnSize.L,
                            ),
                            DataColumn2(
                              label: Text("Depto"),
                              size: ColumnSize.L,
                            ),
                            DataColumn2(
                              label: Text("Cochera"),
                              size: ColumnSize.S,
                            ),
                            DataColumn2(
                              label: Text("Tipo"),
                              size: ColumnSize.S,
                            ),
                            // 👉 Nueva columna
                            DataColumn2(
                              label: Text("Presentismo"),
                              size: ColumnSize.S,
                            ),
                          ],
                          empty: const Center(
                            child: Text(
                              "No hay registros para mostrar.",
                            ),
                          ),
                          rowsPerPage: 10,
                          availableRowsPerPage: const [10, 20, 50],
                          showFirstLastButtons: true,
                          wrapInCard: false,
                          source: _ReportsDataSource(records: filtered),
                        ),
        ),
      ],
    ),
  );
}
}


/// PICKER DE RANGO DE FECHAS

class _DateRangePicker extends StatelessWidget {
  final ReportsState state;
  final ReportsController controller;

  const _DateRangePicker({
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024, 1, 1),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDateRange: DateTimeRange(
              start: state.filter.range.start,
              end: state.filter.range.end,
            ),
            locale: const Locale('es', 'ES'),
          );
          if (picked != null) controller.setDateRange(picked);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.date_range, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                "Desde: ${df.format(state.filter.range.start)} → "
                "Hasta: ${df.format(state.filter.range.end)}",
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// FILTROS (BUSCADOR + DEPARTAMENTOS)

class _FiltersRow extends ConsumerStatefulWidget {
  final Function(String) onSearch;
  final Function(String?) onDeptSelected;

  const _FiltersRow({
    required this.onSearch,
    required this.onDeptSelected,
  });

  @override
  ConsumerState<_FiltersRow> createState() => _FiltersRowState();
}

class _FiltersRowState extends ConsumerState<_FiltersRow> {
  String? selectedDept;

  @override
  Widget build(BuildContext context) {
    
    final departmentsAsync = ref.watch(departmentsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          
          Expanded(
            child: TextField(
              onChanged: widget.onSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Buscar usuario / depto / cochera / tipo",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Dropdown de departamentos del establecimiento actual
          departmentsAsync.when(
            data: (list) {
              return DropdownButton<String?>(
                value: selectedDept,
                hint: const Text("Departamentos"),
                onChanged: (value) {
                  setState(() {
                    selectedDept = value == "ALL" ? null : value;
                  });
                  widget.onDeptSelected(selectedDept);
                },
                items: [
                  const DropdownMenuItem(
                    value: "ALL",
                    child: Text("Todos"),
                  ),
                  ...list.map(
                    (d) => DropdownMenuItem(
                      value: d["id"],
                      child: Text(d["name"]),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (error, stackTrace) => const Text("Error deps"),
          ),
        ],
      ),
    );
  }
}


/// KPI CARDS

class _KpiRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _kpiCard("Ocupación", "${state.occupancyPercent.toStringAsFixed(1)}%"),
          _kpiCard("Liberadas", "${state.totalLiberated}"),
          _kpiCard("Reservadas", "${state.totalBooked}"),
          _kpiCard("Total Cocheras", "${state.totalSpots}"),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


/// TOTALES (LIBRES / RESERVADAS)
class _TotalsRow extends StatelessWidget {
  final List<DetailedReportRecord> records;
  const _TotalsRow({required this.records});

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    final booked = records.where((e) => e.status == "BOOKED").length;
    final available = records.where((e) => e.status == "AVAILABLE").length;

    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat("Total", total, Colors.black),
          _stat("Reservadas", booked, Colors.green),
          _stat("Libres", available, Colors.blue),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          "$value",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


/// DATA SOURCE PARA PaginatedDataTable2
class _ReportsDataSource extends DataTableSource {
  final List<DetailedReportRecord> records;
  final DateFormat _df = DateFormat('dd/MM/yyyy');

  _ReportsDataSource({required this.records});

@override
DataRow? getRow(int index) {
  if (index >= records.length) return null;
  final r = records[index];

  final statusColor =
      r.status == "BOOKED" ? Colors.green : Colors.blue;

  // Normalizamos fechas para comparar solo el día
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final recordDay = DateTime(
    r.releaseDate.year,
    r.releaseDate.month,
    r.releaseDate.day,
  );

  Widget presentismoWidget;

  if (r.status != "BOOKED") {
    // No aplica presentismo
    presentismoWidget = const Text("N/A");
  } else if (recordDay.isAfter(today)) {
    // Reserva futura siempre pendiente
    presentismoWidget = Row(
      children: const [
        Icon(Icons.schedule, color: Colors.grey, size: 18),
        SizedBox(width: 4),
        Text("Pendiente"),
      ],
    );
  } else if (recordDay.isAtSameMomentAs(today)) {
    // Hoy: sólo cuenta si ya marcó presencia
    if (r.presenceConfirmed == true) {
      presentismoWidget =
          const Icon(Icons.check, color: Colors.green);
    } else {
      presentismoWidget = Row(
        children: const [
          Icon(Icons.schedule, color: Colors.grey, size: 18),
          SizedBox(width: 4),
          Text("Pendiente"),
        ],
      );
    }
  } else {
    // Día pasado: presencia cerrada
    if (r.presenceConfirmed == true) {
      presentismoWidget =
          const Icon(Icons.check, color: Colors.green);
    } else {
      presentismoWidget =
          const Icon(Icons.close, color: Colors.red);
    }
  }

  return DataRow(
    cells: [
      DataCell(Text(_df.format(r.releaseDate))), 
      DataCell(
        Text(
          r.status,
          style: TextStyle(color: statusColor),
        ),
      ),
      DataCell(Text(r.userName ?? "-")),
      DataCell(Text(r.departmentName ?? "-")),
      DataCell(Text(r.spotName ?? "-")),
      DataCell(Text(r.spotType ?? "-")),
      DataCell(presentismoWidget),
    ],
  );
}



  @override
  int get rowCount => records.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
