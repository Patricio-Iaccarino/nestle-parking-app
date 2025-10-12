import 'package:cocheras_nestle_web/features/auth/domain/models/app_user.dart';
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
    if (!doc.exists) {
      final newUser = AppUser(uid: uid, email: email, role: 'user');
      await _firestore.collection('users').doc(uid).set(newUser.toMap());
      _cachedUser = newUser;
    } else {
      _cachedUser = AppUser.fromMap(doc.data()!, uid);
    }

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
