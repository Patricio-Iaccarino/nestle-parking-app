import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/vehicles/domain/vehicle_model.dart';

class VehiclesRepository {
  final FirebaseFirestore _firestore;
  VehiclesRepository(this._firestore);

  Future<List<Vehicle>> getAllVehicles() async {
    final snap = await _firestore.collection('vehicles').get();
    return snap.docs
        .map((d) => Vehicle.fromMap(d.data(), d.id))
        .toList();
  }
}

final vehiclesRepositoryProvider = Provider<VehiclesRepository>((ref) {
  return VehiclesRepository(FirebaseFirestore.instance);
});
