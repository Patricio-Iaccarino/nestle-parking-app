import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

class ReservationsRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger(); 

  ReservationsRepository(this._firestore);

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<SpotRelease>> getReservations(
    String establishmentId, {
    DateTime? date,
  }) async {
    try {
      Query query = _firestore
          .collection('spotReleases')
          .where('establishmentId', isEqualTo: establishmentId);

      if (date != null) {
        final start = _startOfDay(date);
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));

        query = query
            .where('releaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('releaseDate', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      final snapshot = await query.get();

      _logger.i("✅ Firestore devolvió ${snapshot.docs.length} documentos");

      for (var doc in snapshot.docs) {
        _logger.i("📄 DOC: ${doc.id} => ${doc.data()}");
      }

      return snapshot.docs.map((doc) {
        try {
          return SpotRelease.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        } catch (e) {
          _logger.e("ERROR parseando doc ${doc.id}", error: e);
          rethrow;
        }
      }).toList();
    } catch (e, stack) {
      _logger.e("ERROR TOTAL EN getReservations()", error: e, stackTrace: stack);
      
      throw Exception('No se pudieron cargar las reservaciones.');
    }
  }

  Future<void> createRelease({
    required String establishmentId,
    required String departmentId,
    required String parkingSpotId,
    required String spotNumber,
    required String releasedByUserId, // titular
    required DateTime releaseDate, // día completo
  }) async {
    final day = _startOfDay(releaseDate);

    // Evitar duplicado: misma cochera + mismo día
    final dupQuery = await _firestore
        .collection('spotReleases')
        .where('parkingSpotId', isEqualTo: parkingSpotId)
        .where('releaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
        .where('releaseDate', isLessThan: Timestamp.fromDate(day.add(const Duration(days: 1))))
        .limit(1)
        .get();

    if (dupQuery.docs.isNotEmpty) {
      throw Exception('Ya existe una liberación para esa cochera en ese día.');
    }

    final data = SpotRelease(
      id: '',
      parkingSpotId: parkingSpotId,
      spotNumber: spotNumber,
      establishmentId: establishmentId,
      departmentId: departmentId,
      releaseDate: day, // almacenamos normalizado
      status: 'AVAILABLE',
      releasedByUserId: releasedByUserId,
      bookedByUserId: null,
    ).toMap();

    await _firestore.collection('spotReleases').add(data);
  }

    Future<void> createReleaseRange({
    required String establishmentId,
    required String departmentId,
    required String parkingSpotId,
    required String spotNumber,
    required String releasedByUserId, // titular
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Normalizamos a inicio de día
    final DateTime start = _startOfDay(startDate);
    final DateTime end = _startOfDay(endDate);

    if (end.isBefore(start)) {
      throw Exception('La fecha fin no puede ser anterior a la fecha inicio.');
    }

    // 1) Verificar que no haya ya liberaciones para esa cochera en el rango
    final dupSnap = await _firestore
        .collection('spotReleases')
        .where('parkingSpotId', isEqualTo: parkingSpotId)
        .where('releaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where(
          'releaseDate',
          isLessThan: Timestamp.fromDate(
            end.add(const Duration(days: 1)),
          ),
        )
        .limit(1)
        .get();

    if (dupSnap.docs.isNotEmpty) {
      throw Exception(
        'Ya existe una liberación para esa cochera en alguna fecha del rango seleccionado.',
      );
    }

    // 2) Crear un doc por cada día del rango
    final batch = _firestore.batch();

    DateTime current = start;
    while (!current.isAfter(end)) {
      final docRef = _firestore.collection('spotReleases').doc();

      final data = SpotRelease(
        id: docRef.id,
        parkingSpotId: parkingSpotId,
        spotNumber: spotNumber,
        establishmentId: establishmentId,
        departmentId: departmentId,
        releaseDate: current,
        status: 'AVAILABLE',
        releasedByUserId: releasedByUserId,
        bookedByUserId: null,
      ).toMap();

      batch.set(docRef, data);
      current = current.add(const Duration(days: 1));
    }

    await batch.commit();
  }


  Future<void> reserveRelease({
    required String releaseId,
    required String bookedByUserId, // suplente
  }) async {
    final ref = _firestore.collection('spotReleases').doc(releaseId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('La liberación no existe.');
      }
      final data = snap.data() as Map<String, dynamic>;
      if ((data['status'] as String?) != 'AVAILABLE') {
        throw Exception('La liberación ya no está disponible.');
      }
      tx.update(ref, {
        'status': 'BOOKED',
        'bookedByUserId': bookedByUserId,
      });
    });
  }

  Future<void> cancelReservation({
    required String releaseId,
  }) async {
    final ref = _firestore.collection('spotReleases').doc(releaseId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('La liberación no existe.');
      }
      final data = snap.data() as Map<String, dynamic>;
      if ((data['status'] as String?) != 'BOOKED') {
        throw Exception('No se puede cancelar: no está en estado BOOKED.');
      }
      tx.update(ref, {
        'status': 'AVAILABLE',
        'bookedByUserId': null,
      });
    });
  }
}

final reservationsRepositoryProvider = Provider<ReservationsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return ReservationsRepository(firestore);
});
