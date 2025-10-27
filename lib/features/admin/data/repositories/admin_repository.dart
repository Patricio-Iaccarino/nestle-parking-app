import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  // --- 🔹 ESTABLISHMENTS ---
  Future<List<Establishment>> getAllEstablishments() async {
    final snapshot = await _firestore.collection('establishments').get();
    return snapshot.docs
        .map((doc) => Establishment.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createEstablishment(Establishment establishment) async {
    final docRef = _firestore.collection('establishments').doc();
    await docRef.set(establishment.copyWith(id: docRef.id).toMap());
  }

  Future<void> updateEstablishment(Establishment establishment) async {
    if (establishment.id.isEmpty) throw Exception('El id no puede ser vacío');
    await _firestore
        .collection('establishments')
        .doc(establishment.id)
        .update(establishment.toMap());
  }

  Future<void> deleteEstablishment(String id) async {
    await _firestore.collection('establishments').doc(id).delete();
  }

  // --- 🔹 DEPARTMENTS ---
  Future<List<Department>> getDepartmentsByEstablishment(
    String establishmentId,
  ) async {
    final snapshot = await _firestore
        .collection('departments')
        .where('establishmentId', isEqualTo: establishmentId)
        .get();

    return snapshot.docs
        .map((doc) => Department.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createDepartment(Department department) async {
    final docRef = _firestore.collection('departments').doc();
    await docRef.set(department.copyWith(id: docRef.id).toMap());
  }

  Future<void> updateDepartment(Department department) async {
    if (department.id.isEmpty) throw Exception('El id no puede ser vacío');
    await _firestore
        .collection('departments')
        .doc(department.id)
        .update(department.toMap());
  }

  Future<void> deleteDepartment(String id) async {
    await _firestore.collection('departments').doc(id).delete();
  }

  // --- 🔹 PARKING SPOTS ---
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
    // 1. Pide a Firestore que genere una referencia con un ID nuevo
    final docRef = _firestore.collection('parkingSpots').doc();

    // 2. Usa copyWith para crear un nuevo objeto 'spot' con ese ID
    //    (Asumo que tu modelo ParkingSpot tiene 'copyWith' y 'toMap' como los otros)
    final spotWithId = spot.copyWith(id: docRef.id);

    // 3. Guarda el objeto con el ID correcto
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

  // --- 🔹 USERS ---
  Future<List<AppUser>> getUsersByDepartment(String departmentId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('departmentId', isEqualTo: departmentId)
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<AppUser>> getAllTitularUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'TITULAR')
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createUser(AppUser user) async {
    final docRef = _firestore.collection('users').doc();
    await docRef.set(user.copyWith(id: docRef.id).toMap());
  }

  Future<void> updateUser(AppUser user) async {
    if (user.id.isEmpty) throw Exception('El id no puede ser vacío');
    await _firestore.collection('users').doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String id) async {
    await _firestore.collection('users').doc(id).delete();
  }

  Future<void> assignAdmin(String userId, String establishmentId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': 'ADMIN',
      'establishmentId': establishmentId,
    });
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
    required String establishmentId,
  }) async {
    String establishmentName = 'Nombre No Encontrado'; // Valor por defecto

    try {
      final establishmentDoc = await _firestore
          .collection('establishments')
          .doc(establishmentId)
          .get();

      if (establishmentDoc.exists) {
        establishmentName =
            establishmentDoc.data()?['name'] ?? establishmentName;
        // ------------------------------------
      } else {
        print('   ❌ Establecimiento NO encontrado con ID: $establishmentId');
      }
      // --------------------------------------------------
    } catch (e) {
      print('   ❗️ ERROR buscando nombre de establecimiento: $e');
      // ---------------------------------------------
    }

    await _firestore.collection('users').doc(userId).update({
      'role': role,
      'establishmentId': establishmentId,
      'establishmentName': establishmentName,
    });
  }

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
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

      return snapshot.docs.map((doc) {
        return SpotRelease.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
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
