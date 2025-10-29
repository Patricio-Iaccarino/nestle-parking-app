import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/report_models.dart';

/// --------------------------------------------------------------------------
/// 🔹 Repositorio central de reportes
/// --------------------------------------------------------------------------
class ReportsRepository {
  final FirebaseFirestore _db;
  ReportsRepository(this._db);

  // --------------------------------------------------------------------------
  // 📊 REPORTE 1 – Ocupación diaria
  // --------------------------------------------------------------------------
  /// Calcula cuántas reservas están activas, canceladas y totales
  /// usando los campos:
  /// - reservations.status → "active" / "cancelled"
  /// - reservations.createdAt (Timestamp)
  Future<List<DailyOccupancyPoint>> fetchDailyOccupancy(ReportsFilter f) async {
    final startDay = dayFloor(f.range.start);
    final endDay = dayFloor(f.range.end);

    try {
      // 🔸 Traemos las reservas dentro del rango de fechas
      final q = _db
          .collection('reservations')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDay));

      final reservationsSnap = await q.get();

      // 🔸 Agrupamos por día
      final Map<DateTime, _DayAgg> grouped = {};
      for (final doc in reservationsSnap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;

          if (data == null) continue;
          final ts = data['createdAt'];
          if (ts == null || ts is! Timestamp) continue;

          final day = dayFloor(ts.toDate());
          final status = (data['status'] ?? 'active').toString().toLowerCase();

          grouped.putIfAbsent(day, () => _DayAgg());

          if (status == 'active') grouped[day]!.active++;
          if (status == 'cancelled') grouped[day]!.cancelled++;
          grouped[day]!.total++;
        } catch (e) {
          print('⚠️ Error procesando documento ${doc.id}: $e');
        }
      }

      // 🔸 Generamos lista continua de días (aunque no haya reservas)
      final List<DailyOccupancyPoint> result = [];
      for (DateTime d = startDay;
          !d.isAfter(endDay);
          d = d.add(const Duration(days: 1))) {
        final agg = grouped[d] ?? _DayAgg();
        result.add(DailyOccupancyPoint(
          day: d,
          occupied: agg.active,
          availableForSubstitutes: agg.cancelled,
          reservedBySubstitutes: agg.total,
        ));
      }

      // Log resumen
      final totalActive =
          grouped.values.fold<int>(0, (sum, e) => sum + e.active);
      final totalCancelled =
          grouped.values.fold<int>(0, (sum, e) => sum + e.cancelled);
      print(
          '✅ Reporte 1 listo. Activas: $totalActive | Canceladas: $totalCancelled');

      return result;
    } catch (e, st) {
      print('❌ Error en fetchDailyOccupancy: $e\n$st');
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // 🏢 REPORTE 2 – Uso por departamento
  // --------------------------------------------------------------------------
  /// Cuenta cuántas reservas activas hubo agrupadas por departmentId
  Future<Map<String, int>> fetchUsageByDepartment(ReportsFilter f) async {
    final startDay = dayFloor(f.range.start);
    final endDay = dayFloor(f.range.end);

    try {
      final q = _db
          .collection('reservations')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDay))
          .where('status', isEqualTo: 'active');

      final reservationsSnap = await q.get();

      // 🔹 Cache local de usuarios (para no hacer una query por reserva)
      final Map<String, String> userDeptCache = {};
      final Map<String, int> perDept = {};

      for (final doc in reservationsSnap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final ownerId = data['ownerId'];
          if (ownerId == null) continue;

          // ✅ Cacheamos departmentId del usuario
          if (!userDeptCache.containsKey(ownerId)) {
            final userSnap = await _db.collection('users').doc(ownerId).get();
            final deptId =
                (userSnap.data()?['departmentId'] ?? 'Desconocido').toString();
            userDeptCache[ownerId] = deptId;
          }

          final dept = userDeptCache[ownerId]!;
          perDept.update(dept, (v) => v + 1, ifAbsent: () => 1);
        } catch (e) {
          print('⚠️ Error procesando reserva por depto ${doc.id}: $e');
        }
      }

      print('✅ Reporte 2 listo (${perDept.length} departamentos)');
      return perDept;
    } catch (e, st) {
      print('❌ Error en fetchUsageByDepartment: $e\n$st');
      return {};
    }
  }

  // --------------------------------------------------------------------------
  // 👥 REPORTE 3 – Reservas de suplentes
  // --------------------------------------------------------------------------
  /// Cuenta reservas activas realizadas por usuarios con rol SUPLENTE
  Future<int> countSubstituteReservations(ReportsFilter f) async {
    final startDay = dayFloor(f.range.start);
    final endDay = dayFloor(f.range.end);

    try {
      final usersSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'SUPLENTE')
          .get();

      final supplUserIds = usersSnap.docs.map((e) => e.id).toSet();

      final reservationsSnap = await _db
          .collection('reservations')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDay))
          .where('status', isEqualTo: 'active')
          .get();

      final count = reservationsSnap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final ownerId = data?['ownerId'];
        return ownerId != null && supplUserIds.contains(ownerId);
      }).length;

      print('✅ Reporte 3 listo. Reservas de suplentes: $count');
      return count;
    } catch (e, st) {
      print('❌ Error en countSubstituteReservations: $e\n$st');
      return 0;
    }
  }

  // --------------------------------------------------------------------------
  // 🚗 REPORTE 4 – Liberaciones de titulares
  // --------------------------------------------------------------------------
  /// Usa la colección `spot_releases` con status: "AVAILABLE" / "BOOKED"
  Future<Map<String, int>> fetchReleasesStats(ReportsFilter f) async {
    final startDay = dayFloor(f.range.start);
    final endDay = dayFloor(f.range.end);

    try {
      final q = _db
          .collection('spot_releases')
          .where('releaseDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
          .where('releaseDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDay));

      final releasesSnap = await q.get();

      int available = 0;
      int booked = 0;

      for (final doc in releasesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final status = (data['status'] ?? '').toString().toUpperCase();
        if (status == 'AVAILABLE') available++;
        if (status == 'BOOKED') booked++;
      }

      final total = releasesSnap.size;
      print('✅ Reporte 4 listo. Disponibles: $available | Reservadas: $booked');

      return {
        'available': available,
        'booked': booked,
        'total': total,
      };
    } catch (e, st) {
      print('❌ Error en fetchReleasesStats: $e\n$st');
      return {'available': 0, 'booked': 0, 'total': 0};
    }
  }
}

/// --------------------------------------------------------------------------
/// 🔹 Clase auxiliar interna para acumular conteos diarios
/// --------------------------------------------------------------------------
class _DayAgg {
  int active = 0;
  int cancelled = 0;
  int total = 0;
}
