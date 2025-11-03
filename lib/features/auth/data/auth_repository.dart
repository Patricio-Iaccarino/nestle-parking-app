import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _cachedUser;

  AppUser? get currentUser => _cachedUser;

  Future<AppUser?> signIn(String email, String password) async {
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = userCred.user!.uid;

    final doc = await _firestore.collection('users').doc(uid).get();

    // --- CORRECCIÓN ---
    if (!doc.exists) {
      // Si el usuario se autenticó pero no tiene perfil en Firestore,
      // significa que es un usuario inválido para esta app. Lo echamos.
      await _auth.signOut();
      _cachedUser = null;
      throw Exception(
        'Este usuario no está registrado en la base de datos de la aplicación.',
      );
    } else {
      // El usuario sí existe, continuamos normal.
      _cachedUser = AppUser.fromMap(doc.data()!, uid);
    }
    // ------------------

    return _cachedUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }

  Future<List<AppUser>> getAllAdmins() async {
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    return query.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  bool get isLoggedIn => _auth.currentUser != null;
}
