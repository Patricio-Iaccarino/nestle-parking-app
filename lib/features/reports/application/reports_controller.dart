import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../domain/report_models.dart';
import '../data/repositories/reports_repository.dart';

// auth provider
import '../../../features/auth/presentation/auth_controller.dart';


/// PROVIDER DEL REPO

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(FirebaseFirestore.instance);
});


/// PROVIDER → Departamentos del establecimiento actual

final departmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);

  // Usuario logueado
  final authState = ref.watch(authControllerProvider);
  final user = authState.value;
  final estId = user?.establishmentId;

  if (estId == null || estId.isEmpty) {
    return [];
  }

  return repo.fetchDepartmentsByEstablishment(estId);
});


/// ESTADO DEL REPORTE DETALLADO + KPIs

class ReportsState {
  final bool loading;
  final ReportsFilter filter;
  final List<DetailedReportRecord> detailed;
  final String? error;

  // KPIs
  final int totalSpots;
  final int totalLiberated;
  final int totalBooked;
  final int occupancyPercent;

  const ReportsState({
    required this.loading,
    required this.filter,
    required this.detailed,
    this.error,
    this.totalSpots = 0,
    this.totalLiberated = 0,
    this.totalBooked = 0,
    this.occupancyPercent = 0,
  });

  ReportsState copyWith({
    bool? loading,
    ReportsFilter? filter,
    List<DetailedReportRecord>? detailed,
    String? error,
    int? totalSpots,
    int? totalLiberated,
    int? totalBooked,
    int? occupancyPercent,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      filter: filter ?? this.filter,
      detailed: detailed ?? this.detailed,
      error: error,
      totalSpots: totalSpots ?? this.totalSpots,
      totalLiberated: totalLiberated ?? this.totalLiberated,
      totalBooked: totalBooked ?? this.totalBooked,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
    );
  }
}


/// CONTROLLER PRINCIPAL

final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);

class ReportsController extends Notifier<ReportsState> {
  late ReportsRepository _repo;
  final Logger _logger = Logger();

  @override
  ReportsState build() {
    _repo = ref.read(reportsRepositoryProvider);

    final authState = ref.watch(authControllerProvider);
    final user = authState.value;

    final adminEstId = user?.establishmentId;
    _logger.i("Establecimiento para reportes: $adminEstId");

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

    // Primera carga del reporte
    Future.microtask(loadReport);
    return initialState;
  }

  /// Cambiar rango de fechas
  void setDateRange(DateTimeRange picked) {
    final updated = state.filter.copyWith(
      range: DateRange(start: picked.start, end: picked.end),
    );

    state = state.copyWith(filter: updated);
    loadReport();
  }

  /// Filtro por usuario (lo dejamos por si se usa en otra UI a futuro)
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

  /// Filtro por departamento
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

  
  /// Carga de datos + KPIs
 
  Future<void> loadReport() async {
  state = state.copyWith(loading: true, error: null);

  try {
    final f = state.filter;

    if (f.establishmentId == null || f.establishmentId!.isEmpty) {
      throw Exception("Establecimiento no definido para reportes.");
    }

    // Normalizar fechas al día completo
    DateTime normalizeStart(DateTime d) =>
        DateTime(d.year, d.month, d.day); 

    DateTime normalizeEnd(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59, 999); 

    final startDay = normalizeStart(f.range.start);
    final endDay = normalizeEnd(f.range.end);

    // 1. Obtener registros detallados usando el rango normalizado
    final data = await _repo.fetchDetailedDailyReport(
      start: startDay,
      end: endDay,
      establishmentId: f.establishmentId!,
      departmentId: f.departmentId,
      userId: f.userId,
    );

    // 2. KPIs de cantidad
    final totalBooked = data.where((e) => e.status == "BOOKED").length;
    final totalLiberated = data.where((e) => e.status == "AVAILABLE").length;

    // 3. Cocheras totales
    final totalSpots = await _repo.countTotalSpots(f.establishmentId!);

    // 4. Cálculo de ocupación basado en días
    final daysInRange = endDay
            .difference(startDay)
            .inDays +
        1;

    final totalCarDays = daysInRange * totalSpots;
    final occupiedCarDays = totalCarDays - totalLiberated;

    final occupancyPercent = totalCarDays == 0
        ? 0
        : ((occupiedCarDays / totalCarDays) * 100).round();

    // Logs informativos
    _logger.i("Reporte cargado: ${data.length} filas");
    _logger.i("Rango normalizado: $startDay → $endDay");
    _logger.i("Días en rango: $daysInRange");
    _logger.i("Total spots: $totalSpots");
    _logger.i("Días-cochera totales: $totalCarDays");
    _logger.i("Liberaciones: $totalLiberated");
    _logger.i("Ocupación %: $occupancyPercent");

    state = state.copyWith(
      loading: false,
      detailed: data,
      totalSpots: totalSpots,
      totalBooked: totalBooked,
      totalLiberated: totalLiberated,
      occupancyPercent: occupancyPercent,
    );
  } catch (e, st) {
    _logger.e("Error reporte", error: e, stackTrace: st);
    state = state.copyWith(loading: false, error: e.toString());
  }
}

}
