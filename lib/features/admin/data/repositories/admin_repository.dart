import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';


class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  Future<void> assignAdmin(String userId, String establishmentId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': 'ADMIN',
      'establishmentId': establishmentId,
    });
  }

  // --- 🔹 RESERVATIONS (NUEVO) ---
  Future<List<SpotRelease>> getReservations(
    String establishmentId, {
    DateTime? date,
  }) async {
    try {
      Query query = _firestore
          .collection('spotReleases')
          .where('establishmentId', isEqualTo: establishmentId);

      if (date != null) {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        query = query
            .where('releaseDate', isGreaterThanOrEqualTo: startOfDay)
            .where('releaseDate', isLessThanOrEqualTo: endOfDay);
      }

      final snapshot = await query.get();

      print("✅ Firestore devolvió ${snapshot.docs.length} documentos");

      for (var doc in snapshot.docs) {
        print("📄 DOC: ${doc.id} => ${doc.data()}");
      }

      return snapshot.docs.map((doc) {
        try {
          return SpotRelease.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        } catch (e) {
          print("❌ ERROR parseando doc ${doc.id}: $e");
          rethrow;
        }
      }).toList();
    } catch (e) {
      print("❌ ERROR TOTAL getReservations: $e");
      throw Exception('No se pudieron cargar las reservaciones.');
    }
  }

  Future<List<ParkingSpot>> getParkingSpotsByEstablishment(
    String establishmentId,
  ) async {
    final snapshot = await _firestore
        .collection('parkingSpots')
        .where('establishmentId', isEqualTo: establishmentId)
        .get();
    return snapshot.docs
        .map((doc) => ParkingSpot.fromMap(doc.data(), doc.id))
        .toList();
  }
}
