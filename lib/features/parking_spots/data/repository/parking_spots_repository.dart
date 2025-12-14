import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParkingSpotsRepository {
  final FirebaseFirestore _firestore;
  ParkingSpotsRepository(this._firestore);

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

  /// 🔹 Obtiene el máximo de cocheras permitido para un departamento
  Future<int?> _getMaxSpotsForDepartment(String departmentId) async {
    if (departmentId.isEmpty) return null;

    final deptSnap =
        await _firestore.collection('departments').doc(departmentId).get();

    if (!deptSnap.exists) return null;

    final data = deptSnap.data();
    if (data == null) return null;

    final max = (data['parkingSpotsCount'] as num?)?.toInt();
    return max;
  }

  /// 🔹 Cuenta cuántas cocheras tiene hoy un departamento
  Future<int> _countSpotsForDepartment(String departmentId) async {
    final snap = await _firestore
        .collection('parkingSpots')
        .where('departmentId', isEqualTo: departmentId)
        .get();

    return snap.size;
  }

  Future<void> createParkingSpot(ParkingSpot spot) async {
    // 1) Validar capacidad del depto (si tiene configurado parkingSpotsCount)
    final maxSpots = await _getMaxSpotsForDepartment(spot.departmentId);

    if (maxSpots != null && maxSpots > 0) {
      final currentCount = await _countSpotsForDepartment(spot.departmentId);

      if (currentCount >= maxSpots) {
        // 👇 Importante: no creamos el documento y avisamos con un mensaje claro
        throw Exception(
          'No se pueden crear más cocheras para este departamento. '
          'Límite configurado: $maxSpots.',
        );
      }
    }

    // 2) Crear cochera normalmente
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

final parkingSpotsRepositoryProvider = Provider<ParkingSpotsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return ParkingSpotsRepository(firestore);
});
