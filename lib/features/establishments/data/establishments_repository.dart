import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EstablishmentsRepository {
  final FirebaseFirestore _firestore;
  EstablishmentsRepository(this._firestore);

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
}

final establishmentsRepositoryProvider = Provider<EstablishmentsRepository>((
  ref,
) {
  final firestore = FirebaseFirestore.instance;
  return EstablishmentsRepository(firestore);
});
