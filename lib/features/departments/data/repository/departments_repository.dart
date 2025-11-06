// lib/features/departments/data/departments_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DepartmentsRepository {
  final FirebaseFirestore _firestore;
  DepartmentsRepository(this._firestore);

  // --- 🔹 MÉTODOS MOVIDOS DESDE ADMIN_REPOSITORY 🔹 ---

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
}

// --- 🔹 EL PROVIDER VA EN EL MISMO ARCHIVO 🔹 ---
final departmentsRepositoryProvider = Provider<DepartmentsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return DepartmentsRepository(firestore);
});