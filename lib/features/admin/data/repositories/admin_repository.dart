import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  Future<void> assignAdmin(String userId, String establishmentId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': 'ADMIN',
      'establishmentId': establishmentId,
    });
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
