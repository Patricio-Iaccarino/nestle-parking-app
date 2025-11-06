// lib/features/reservations/data/repository/reservations_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReservationsRepository {
  final FirebaseFirestore _firestore;
  ReservationsRepository(this._firestore);

  // --- 🔹 MÉTODO MOVIDO DESDE ADMIN_REPOSITORY 🔹 ---

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

      // (Tus prints de diagnóstico están aquí, los dejamos)
      print("✅ Firestore devolvió ${snapshot.docs.length} documentos");
      for (var doc in snapshot.docs) {
        print("📄 DOC: ${doc.id} => ${doc.data()}");
      }

      return snapshot.docs.map((doc) {
        try {
          return SpotRelease.fromMap(doc.data() as Map<String, dynamic>, doc.id);
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
}

// --- 🔹 EL PROVIDER VA EN EL MISMO ARCHIVO 🔹 ---
final reservationsRepositoryProvider = Provider<ReservationsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return ReservationsRepository(firestore);
});