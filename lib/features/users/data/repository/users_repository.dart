// lib/features/users/data/repository/users_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UsersRepository {
  final FirebaseFirestore _firestore;
  UsersRepository(this._firestore);

  // --- 🔹 MÉTODOS DE USUARIOS 🔹 ---

  Future<AppUser> getUserProfile(String uid) async {
    final docSnap = await _firestore.collection('users').doc(uid).get();
    if (!docSnap.exists) {
      throw Exception('No se encontró el perfil de usuario.');
    }
    return AppUser.fromMap(docSnap.data()!, docSnap.id);
  }

  Future<List<AppUser>> getUsersForEstablishment(String establishmentId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('establishmentId', isEqualTo: establishmentId)
        .get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<AppUser>> getAdminUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

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
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> updateUser(AppUser user) async {
    if (user.id.isEmpty) throw Exception('El id no puede ser vacío');
    await _firestore.collection('users').doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String id) async {
    await _firestore.collection('users').doc(id).delete();
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
    required String establishmentId,
  }) async {
    String establishmentName = 'Nombre No Encontrado'; 
    
    try {
      final establishmentDoc = await _firestore
          .collection('establishments')
          .doc(establishmentId)
          .get();

      if (establishmentDoc.exists) {
        establishmentName =
            establishmentDoc.data()?['name'] ?? establishmentName;
      }
    } catch (e) {
      print(' ❗️ ERROR buscando nombre de establecimiento: $e');
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
}

// --- 🔹 EL PROVIDER VA EN EL MISMO ARCHIVO 🔹 ---
final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return UsersRepository(firestore);
});