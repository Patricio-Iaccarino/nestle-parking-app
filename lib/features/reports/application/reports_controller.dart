import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain/report_models.dart';
import '../infrastructure/reports_repository.dart';

// ✅ auth provider
import '../../../features/auth/presentation/auth_controller.dart';

/// ─────────────────────────────────────────────────────
/// PROVIDER DEL REPO
/// ─────────────────────────────────────────────────────
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(FirebaseFirestore.instance);
});

// Obtener departamentos
final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.fetchDepartments();
});

// Obtener usuarios
final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.fetchUsers();
});

/// ─────────────────────────────────────────────────────
/// ESTADO DEL REPORTE DETALLADO + KPIs
/// ─────────────────────────────────────────────────────
class ReportsState {
  final bool loading;
  final ReportsFilter filter;
  final List<DetailedReportRecord> detailed;
  final String? error;

  // ✅ NUEVOS CAMPOS (KPIs)
  final int totalSpots;
  final int totalLiberated;
  final int totalBooked;

  const ReportsState({
    required this.loading,
    required this.filter,
    required this.detailed,
    this.error,
    this.totalSpots = 0,
    this.totalLiberated = 0,
    this.totalBooked = 0,
  });

  ReportsState copyWith({
    bool? loading,
    ReportsFilter? filter,
    List<DetailedReportRecord>? detailed,
    String? error,
    int? totalSpots,
    int? totalLiberated,
    int? totalBooked,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      filter: filter ?? this.filter,
      detailed: detailed ?? this.detailed,
      error: error,
      totalSpots: totalSpots ?? this.totalSpots,
      totalLiberated: totalLiberated ?? this.totalLiberated,
      totalBooked: totalBooked ?? this.totalBooked,
    );
  }
}

/// ─────────────────────────────────────────────────────
/// CONTROLLER PRINCIPAL
/// ─────────────────────────────────────────────────────
final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);

class ReportsController extends Notifier<ReportsState> {
  late ReportsRepository _repo;

  @override
  ReportsState build() {
    _repo = ref.read(reportsRepositoryProvider);

    final authState = ref.watch(authControllerProvider);
    final user = authState.value;

    final adminEstId = user?.establishmentId;
    print("📌 Establecimiento para reportes: $adminEstId");

    final today = DateTime.now();
    final initRange = DateRange(
      start: DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 6)),
      end: DateTime(today.year, today.month, today.day),
    );

    final initialState = ReportsState(
      loading: false,
      filter: ReportsFilter(
        range: initRange,
        establishmentId: adminEstId,
        departmentId: null,
        userId: null,
      ),
      detailed: const [],
    );

    Future.microtask(loadReport);
    return initialState;
  }

  /// Cambiar fechas
  void setDateRange(DateTimeRange picked) {
    final updated = state.filter.copyWith(
      range: DateRange(start: picked.start, end: picked.end),
    );

    state = state.copyWith(filter: updated);
    loadReport();
  }

  /// Filtros
  void setUserFilter(String? userId) {
    final f = state.filter;

    final newFilter = ReportsFilter(
      range: f.range,
      establishmentId: f.establishmentId,
      departmentId: f.departmentId,
      userId: (userId == null || userId.isEmpty) ? null : userId,
    );

    state = state.copyWith(filter: newFilter);
    loadReport();
  }

  void setDeptFilter(String? deptId) {
    final f = state.filter;

    final newFilter = ReportsFilter(
      range: f.range,
      establishmentId: f.establishmentId,
      departmentId: (deptId == null || deptId.isEmpty) ? null : deptId,
      userId: f.userId,
    );

    state = state.copyWith(filter: newFilter);
    loadReport();
  }

  /// ─────────────────────────────────────────────────────
  /// Carga de datos + KPIs
  /// ─────────────────────────────────────────────────────
  Future<void> loadReport() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final f = state.filter;

      // ✅ Obtener registros detallados
      final data = await _repo.fetchDetailedDailyReport(
        start: f.range.start,
        end: f.range.end,
        establishmentId: f.establishmentId,
        departmentId: f.departmentId,
        userId: f.userId,
      );

      // Calcular KPIs desde `data`
     // Contar BOOKED y AVAILABLE 
final totalBooked = data.where((e) => e.status == "BOOKED").length;
final totalLiberated = data.where((e) => e.status == "AVAILABLE").length;


      // ✅ Total cocheras del establecimiento
      final totalSpots = await _repo.countTotalSpots(f.establishmentId!);

      print("✅ Reporte cargado: ${data.length} filas");

      state = state.copyWith(
        loading: false,
        detailed: data,
        totalSpots: totalSpots,
        totalBooked: totalBooked,
        totalLiberated: totalLiberated,
      );
    } catch (e, st) {
      print("❌ Error reporte: $e\n$st");
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
