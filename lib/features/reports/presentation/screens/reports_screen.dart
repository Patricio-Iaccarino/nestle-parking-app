import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/reports_controller.dart';
import '../../domain/report_models.dart';
import '../../../../core/services/export_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/auth_controller.dart';

// 🔹 Provider para departamentos filtrados por establecimiento
final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authControllerProvider).value;
  final estId = auth?.establishmentId;

  if (estId == null) return [];

  final snap = await FirebaseFirestore.instance
      .collection("departments")
      .where("establishmentId", isEqualTo: estId)
      .get();

  return snap.docs
      .map((d) => {
            "id": d.id,
            "name": d["name"] ?? "",
          })
      .toList();
});

// 🔹 Provider para usuarios filtrados por establecimiento
final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authControllerProvider).value;
  final estId = auth?.establishmentId;

  if (estId == null) return [];

  final snap = await FirebaseFirestore.instance
      .collection("users")
      .where("establishmentId", isEqualTo: estId)
      .get();

  return snap.docs
      .map((u) => {
            "id": u.id,
            "name": u["displayName"] ?? "",
          })
      .toList();
});


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

    final filtered = state.detailed.where((e) {
  final s = _searchText.toLowerCase();
  if (s.isEmpty) return true;

  return (e.userName ?? "").toLowerCase().contains(s) ||
         (e.departmentName ?? "").toLowerCase().contains(s) ||
         (e.spotName ?? "").toLowerCase().contains(s);
}).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte de Ocupación de Cocheras"),
        backgroundColor: Colors.red.shade700,
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

          _DateRangePicker(state: state, controller: controller),

          _FiltersRow(
            onSearch: (t) => setState(() => _searchText = t),
            onDeptSelected: controller.setDeptFilter,
            onUserSelected: controller.setUserFilter,
          ),

          _KpiRow(),

          _TotalsRow(records: filtered),

          const Divider(height: 1),

          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Text("⚠️ ${state.error}",
                            style: TextStyle(color: Colors.red.shade800)))
                    : _RecordsTable(records: filtered),
          )
        ],
      ),
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  final ReportsState state;
  final ReportsController controller;

  const _DateRangePicker({required this.state, required this.controller});

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
                "Desde: ${df.format(state.filter.range.start)} "
                "→ Hasta: ${df.format(state.filter.range.end)}",
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




class _FiltersRow extends ConsumerStatefulWidget {
  final Function(String) onSearch;
  final Function(String?) onDeptSelected;
  final Function(String?) onUserSelected;

  const _FiltersRow({
    required this.onSearch,
    required this.onDeptSelected,
    required this.onUserSelected,
  });

  @override
  ConsumerState<_FiltersRow> createState() => _FiltersRowState();
}

class _FiltersRowState extends ConsumerState<_FiltersRow> {
  String? selectedDept;
  String? selectedUser;

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentsProvider);
    final usersAsync = ref.watch(usersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: widget.onSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Buscar usuario / depto / cochera",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 🏢 Departamentos
          departmentsAsync.when(
            data: (list) {
              return DropdownButton<String?>(
                value: selectedDept,
                hint: const Text("Departamentos"),
                onChanged: (value) {
                  setState(() => selectedDept = value == "ALL" ? null : value);
                  widget.onDeptSelected(selectedDept);
                },
                items: [
                  const DropdownMenuItem(
                    value: "ALL",
                    child: Text("Todos"),
                  ),
                  ...list.map((d) => DropdownMenuItem(
                        value: d["id"],
                        child: Text(d["name"]),
                      )),
                ],
              );
            },
            loading: () => const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Text("Error deps"),
          ),

          const SizedBox(width: 12),

          // 👤 Usuarios
          usersAsync.when(
  data: (list) {
    return DropdownButton<String?>(
      value: selectedUser,
      hint: const Text("Usuarios"),
      onChanged: (value) {
        setState(() => selectedUser = value);
        widget.onUserSelected(selectedUser);
      },
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text("Todos"),
        ),
        ...list.map((u) => DropdownMenuItem(
              value: u["id"],
              child: Text(u["name"]),
            )),
      ],
    );
  },
  loading: () => const SizedBox(
    width: 22, height: 22,
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
  error: (_, __) => const Text("Error users"),
),
        ],
      ),
    );
  }
}

class _KpiRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);

    final occupancy = state.totalSpots == 0
        ? 0
        : (state.totalBooked / state.totalSpots * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _kpiCard("Ocupación", "$occupancy%"),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0,2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}



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
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Text("$value",
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _RecordsTable extends StatelessWidget {
  final List<DetailedReportRecord> records;
  const _RecordsTable({required this.records});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
        columns: const [
          DataColumn(label: Text("Fecha")),
          DataColumn(label: Text("Estado")),
          DataColumn(label: Text("Usuario")),
          DataColumn(label: Text("Depto")),
          DataColumn(label: Text("Cochera")),
        ],
        rows: records.map((r) {
          return DataRow(cells: [
            DataCell(Text(df.format(r.releaseDate))),
            DataCell(Text(
              r.status,
              style: TextStyle(
                color: r.status == "BOOKED" ? Colors.green : Colors.blue,
              ),
            )),
            DataCell(Text(r.userName ?? "-")),
            DataCell(Text(r.departmentName ?? "-")),
            DataCell(Text(r.spotName ?? "-")),
          ]);
        }).toList(),
      ),
    );
  }
}
