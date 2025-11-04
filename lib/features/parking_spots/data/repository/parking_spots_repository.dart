// lib/features/parking_spots/data/parking_spots_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParkingSpotsRepository {
  final FirebaseFirestore _firestore;
  ParkingSpotsRepository(this._firestore);

  // --- 🔹 MÉTODOS MOVIDOS DESDE ADMIN_REPOSITORY 🔹 ---

  Future<List<ParkingSpot>> getParkingSpotsByDepartment(
    String departmentId,
  ) async {
    final snapshot = await _firestore
        .collection('parkingSpots')
        .where('departmentId', isEqualTo: departmentId)
        .get();

    return snapshot.docs
        .map((doc) => ParkingSpot.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createParkingSpot(ParkingSpot spot) async {
    final docRef = _firestore.collection('parkingSpots').doc();
    final spotWithId = spot.copyWith(id: docRef.id);
    await docRef.set(spotWithId.toMap());
  }

  Future<void> updateParkingSpot(ParkingSpot spot) async {
    if (spot.id.isEmpty) throw Exception('El id no puede ser vacío');
    await _firestore
        .collection('parkingSpots')
        .doc(spot.id)
        .update(spot.toMap());
  }

  Future<void> deleteParkingSpot(String id) async {
    await _firestore.collection('parkingSpots').doc(id).delete();
  }

  // NOTA: Dejamos 'getParkingSpotsByEstablishment' en AdminRepository por ahora,
  // ya que el Dashboard depende de él. Lo moveremos al final.
}

// --- 🔹 EL PROVIDER VA EN EL MISMO ARCHIVO 🔹 ---
final parkingSpotsRepositoryProvider = Provider<ParkingSpotsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return ParkingSpotsRepository(firestore);
});