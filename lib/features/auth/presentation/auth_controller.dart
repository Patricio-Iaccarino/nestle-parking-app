import 'package:cocheras_nestle_web/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository repository;
  final _firestore = FirebaseFirestore.instance; // agregado para actualizar Firestore

  AuthController(this.repository)
      : super(AsyncValue.data(repository.currentUser));

  Future<AppUser?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await repository.signIn(email, password);
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // para que LoginForm capture errores
    }
  }

  Future<void> signOut() async {
    await repository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> logout() async {
    await repository.signOut();
    state = const AsyncValue.data(null);
  }

  // ✅ NUEVO MÉTODO: actualizar el establecimiento actual del usuario logueado
  Future<void> updateUserEstablishment(String newEstablishmentId) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    try {
      // 1️⃣ Crear copia del usuario con el nuevo establecimiento
      final updatedUser =
          currentUser.copyWith(establishmentId: newEstablishmentId);

      // 2️⃣ Actualizar Firestore
      await _firestore.collection('users').doc(currentUser.id).update({
        'establishmentId': newEstablishmentId,
      });

      // 3️⃣ Actualizar el estado local de autenticación
      state = AsyncData(updatedUser);
    } catch (e) {
      print('⚠️ Error al actualizar establishmentId: $e');
    }
  }
}
