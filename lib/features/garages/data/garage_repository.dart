// lib/features/garages/data/garage_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/garages/domain/models/garage_location_model.dart';

class GarageRepository {
  final FirebaseFirestore _firestore;

  GarageRepository(this._firestore);

  Future<List<GarageLocation>> getAllGarageLocations() async {
    final snapshot = await _firestore.collection('garages').get();

    return snapshot.docs
        .map((doc) => GarageLocation.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> assignAdmin(String garageId, String adminId) async {
    final ref = _firestore.collection('garages').doc(garageId);

    await ref.update({
      'adminIds': FieldValue.arrayUnion([adminId]),
    });
  }

  Future<void> removeAdmin(String garageId, String adminId) async {
    final ref = _firestore.collection('garages').doc(garageId);

    await ref.update({
      'adminIds': FieldValue.arrayRemove([adminId]),
    });
  }

  Future<void> createGarage(GarageLocation garage) async {
    await _firestore.collection('garages').add(garage.toMap());
  }

  Future<void> updateGarage(GarageLocation garage) async {
    await _firestore.collection('garages').doc(garage.id).update(garage.toMap());
  }

  Future<void> deleteGarage(String id) async {
    await _firestore.collection('garages').doc(id).delete();
  }

  Future<void> saveGarage(GarageLocation garage) async {
    if (garage.id.isEmpty) {
      await createGarage(garage);
    } else {
      await updateGarage(garage);
    }
  }
}
