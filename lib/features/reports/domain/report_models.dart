import 'package:cloud_firestore/cloud_firestore.dart';

/// --------------------------------------------------------------------------
/// 🔹 Tipos de reportes disponibles en la app
/// --------------------------------------------------------------------------
enum ReportKind {
  occupancyDaily,     // Ocupación diaria
  byDepartment,       // Uso por departamento
  substitutes,        // Reservas de suplentes
  titularReleases,    // Liberaciones de titulares
}

/// --------------------------------------------------------------------------
/// 🔹 Representa un rango de fechas (desde - hasta)
/// --------------------------------------------------------------------------
class DateRange {
  final DateTime start; // inclusive
  final DateTime end;   // inclusive

  const DateRange({
    required this.start,
    required this.end,
  });

  @override
  String toString() => 'DateRange($start → $end)';
}

/// --------------------------------------------------------------------------
/// 🔹 Punto de datos diario (para el gráfico o listado de ocupación)
/// --------------------------------------------------------------------------
class DailyOccupancyPoint {
  final DateTime day;                // yyyy-mm-dd (a las 00:00)
  final int occupied;                // cocheras ocupadas ese día
  final int availableForSubstitutes; // cocheras disponibles para suplentes
  final int reservedBySubstitutes;   // reservas confirmadas por suplentes

  const DailyOccupancyPoint({
    required this.day,
    required this.occupied,
    required this.availableForSubstitutes,
    required this.reservedBySubstitutes,
  });

  @override
  String toString() =>
      'DailyOccupancyPoint(day: $day, occupied: $occupied, available: $availableForSubstitutes, reserved: $reservedBySubstitutes)';
}

/// --------------------------------------------------------------------------
/// 🔹 Filtros comunes aplicables a todos los reportes
/// --------------------------------------------------------------------------
class ReportsFilter {
  final String? establishmentId;
  final String? departmentId;
  final DateRange range;

  const ReportsFilter({
    required this.range,
    this.establishmentId,
    this.departmentId,
  });

  /// Permite crear una copia modificando solo algunos valores
  ReportsFilter copyWith({
    DateRange? range,
    String? establishmentId,
    String? departmentId,
  }) {
    return ReportsFilter(
      range: range ?? this.range,
      establishmentId: establishmentId ?? this.establishmentId,
      departmentId: departmentId ?? this.departmentId,
    );
  }

  @override
  String toString() =>
      'ReportsFilter(establishmentId: $establishmentId, departmentId: $departmentId, range: $range)';
}

/// --------------------------------------------------------------------------
/// 🔹 Helpers de fecha (para normalización y conversión Firestore)
/// --------------------------------------------------------------------------
DateTime dayFloor(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

Timestamp tsFromDay(DateTime day) => Timestamp.fromDate(day);
