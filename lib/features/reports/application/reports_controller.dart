import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // 🔹 Para usar DateTimeRange
import '../domain/report_models.dart';
import '../infrastructure/reports_repository.dart';

/// --------------------------------------------------------------------------
/// 🔹 Proveedor del repositorio de reportes (acceso a Firestore)
/// --------------------------------------------------------------------------
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(FirebaseFirestore.instance);
});

/// --------------------------------------------------------------------------
/// 🔹 Estado general de la pantalla de reportes
/// --------------------------------------------------------------------------
class ReportsState {
  final bool loading;
  final ReportKind kind;
  final ReportsFilter filter;

  // 🔹 Datos de los diferentes reportes
  final List<DailyOccupancyPoint> daily; // Reporte 1
  final Map<String, int> byDepartment; // Reporte 2
  final int substituteCount; // Reporte 3
  final Map<String, int> releasesStats; // Reporte 4

  final String? error;

  const ReportsState({
    required this.loading,
    required this.kind,
    required this.filter,
    required this.daily,
    required this.byDepartment,
    required this.substituteCount,
    required this.releasesStats,
    this.error,
  });

  ReportsState copyWith({
    bool? loading,
    ReportKind? kind,
    ReportsFilter? filter,
    List<DailyOccupancyPoint>? daily,
    Map<String, int>? byDepartment,
    int? substituteCount,
    Map<String, int>? releasesStats,
    String? error,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      kind: kind ?? this.kind,
      filter: filter ?? this.filter,
      daily: daily ?? this.daily,
      byDepartment: byDepartment ?? this.byDepartment,
      substituteCount: substituteCount ?? this.substituteCount,
      releasesStats: releasesStats ?? this.releasesStats,
      error: error,
    );
  }
}

/// --------------------------------------------------------------------------
/// 🔹 Controlador principal de reportes (Riverpod 3.x)
/// --------------------------------------------------------------------------
final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);

class ReportsController extends Notifier<ReportsState> {
  late ReportsRepository _repo;

  @override
  ReportsState build() {
    _repo = ref.read(reportsRepositoryProvider);

    final today = DateTime.now();
    final initRange = DateRange(
      start: DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 6)),
      end: DateTime(today.year, today.month, today.day),
    );

    // Estado inicial
    final initialState = ReportsState(
      loading: false,
      kind: ReportKind.occupancyDaily,
      filter: ReportsFilter(range: initRange),
      daily: const [],
      byDepartment: const {},
      substituteCount: 0,
      releasesStats: const {},
    );

    // 🔹 Carga inicial automática (primer reporte)
    Future.microtask(load);

    return initialState;
  }

  /// ------------------------------------------------------------------------
  /// 🔹 Cambiar tipo de reporte (dropdown)
  /// ------------------------------------------------------------------------
  void setKind(ReportKind kind) {
    state = state.copyWith(kind: kind);
    load();
  }

  /// ------------------------------------------------------------------------
  /// 🔹 Cambiar filtro completo (por ejemplo: fecha o establecimiento)
  /// ------------------------------------------------------------------------
  void setFilter(ReportsFilter filter) {
    state = state.copyWith(filter: filter);
    load();
  }

  /// ------------------------------------------------------------------------
  /// 🔹 Cambiar rango de fechas desde el selector del calendario
  /// ------------------------------------------------------------------------
  void setDateRange(DateTimeRange picked) {
    final newRange = DateRange(
      start: picked.start,
      end: picked.end,
    );

    // 🧩 Crea un nuevo filtro con el mismo establecimiento y depto, pero rango nuevo
    final updatedFilter = ReportsFilter(
      range: newRange,
      establishmentId: state.filter.establishmentId,
      departmentId: state.filter.departmentId,
    );

    state = state.copyWith(filter: updatedFilter);
    load(); // 🔁 Vuelve a generar el reporte con el nuevo rango
  }

  /// ------------------------------------------------------------------------
  /// 🔹 Cargar los datos del reporte seleccionado
  /// ------------------------------------------------------------------------
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);

    try {
      switch (state.kind) {
        // ------------------------------------------------------------------
        // 📈 Reporte 1 – Ocupación diaria
        // ------------------------------------------------------------------
        case ReportKind.occupancyDaily:
          final data = await _repo.fetchDailyOccupancy(state.filter);
          state = state.copyWith(
            loading: false,
            daily: data,
            error: null,
          );
          break;

        // ------------------------------------------------------------------
        // 🏢 Reporte 2 – Uso por departamento
        // ------------------------------------------------------------------
        case ReportKind.byDepartment:
          final data = await _repo.fetchUsageByDepartment(state.filter);
          state = state.copyWith(
            loading: false,
            byDepartment: data,
            error: null,
          );
          break;

        // ------------------------------------------------------------------
        // 👥 Reporte 3 – Reservas de suplentes
        // ------------------------------------------------------------------
        case ReportKind.substitutes:
          final count = await _repo.countSubstituteReservations(state.filter);
          state = state.copyWith(
            loading: false,
            substituteCount: count,
            error: null,
          );
          break;

        // ------------------------------------------------------------------
        // 🚗 Reporte 4 – Liberaciones de titulares
        // ------------------------------------------------------------------
        case ReportKind.titularReleases:
          final stats = await _repo.fetchReleasesStats(state.filter);
          state = state.copyWith(
            loading: false,
            releasesStats: stats,
            error: null,
          );
          break;
      }

      print('✅ Reporte cargado correctamente: ${state.kind}');
    } catch (e, st) {
      print('❌ Error al cargar reporte ${state.kind}: $e\n$st');
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }
}
