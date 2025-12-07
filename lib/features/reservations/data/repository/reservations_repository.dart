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
            .where('releaseDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('releaseDate',
                isLessThanOrEqualTo: Timestamp.fromDate(end));
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
      _logger.e("ERROR TOTAL EN getReservations()",
          error: e, stackTrace: stack);

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
        .where('releaseDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(day))
        .where(
          'releaseDate',
          isLessThan: Timestamp.fromDate(day.add(const Duration(days: 1))),
        )
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
      throw Exception(
          'La fecha fin no puede ser anterior a la fecha inicio.');
    }

    // 1) Verificar que no haya ya liberaciones para esa cochera en el rango
    final dupSnap = await _firestore
        .collection('spotReleases')
        .where('parkingSpotId', isEqualTo: parkingSpotId)
        .where('releaseDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
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

    // --- PASO 1: PRE-VALIDACIÓN (Fuera de la transacción) ---
    // Leemos el documento para obtener los datos necesarios para la query
    final snapshot = await ref.get();
    
    if (!snapshot.exists) {
      throw Exception('La liberación no existe.');
    }
    
    final data = snapshot.data() as Map<String, dynamic>;
    
    // Si ya está ocupada, fallamos rápido sin gastar lecturas de query
    if (data['status'] != 'AVAILABLE') {
      throw Exception('La liberación ya no está disponible.');
    }

    final String establishmentId = (data['establishmentId'] as String?) ?? '';
    final Timestamp ts = data['releaseDate'] as Timestamp;
    final DateTime releaseDate = ts.toDate();
    
    final DateTime startOfDay = _startOfDay(releaseDate);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    // --- PASO 2: CHEQUEO DE DUPLICADOS (Query compleja) ---
    // Hacemos esto fuera de la transacción para evitar errores en Web
    final dupSnap = await _firestore
        .collection('spotReleases')
        .where('bookedByUserId', isEqualTo: bookedByUserId)
        .where('establishmentId', isEqualTo: establishmentId)
        .where('status', isEqualTo: 'BOOKED') // Solo reservas activas
        .where('releaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('releaseDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    if (dupSnap.docs.isNotEmpty) {
      throw Exception(
        'Ya tenés una cochera reservada para este día en este establecimiento.',
      );
    }

    // --- PASO 3: TRANSACCIÓN DE ESCRITURA ---
    // Ahora que sabemos que el usuario puede reservar, intentamos ganar la cochera.
    await _firestore.runTransaction((tx) async {
      // Leemos de nuevo DENTRO de la transacción (Bloqueo optimista)
      // Esto asegura que nadie nos ganó de mano entre el Paso 1 y el Paso 3.
      final freshSnap = await tx.get(ref);
      
      if (!freshSnap.exists) throw Exception('La liberación no existe.');
      
      final freshData = freshSnap.data() as Map<String, dynamic>;
      
      if (freshData['status'] != 'AVAILABLE') {
        throw Exception('Lo sentimos, alguien más acaba de tomar esta cochera.');
      }

      // Si todo sigue igual, escribimos
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
        throw Exception(
            'No se puede cancelar: no está en estado BOOKED.');
      }
      tx.update(ref, {
        'status': 'AVAILABLE',
        'bookedByUserId': null,
      });
    });
  }
}

final reservationsRepositoryProvider =
    Provider<ReservationsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return ReservationsRepository(firestore);
});
