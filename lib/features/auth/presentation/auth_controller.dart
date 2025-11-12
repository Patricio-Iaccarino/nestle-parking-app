import 'package:cocheras_nestle_web/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart'; 

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
  final _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger(); 

  AuthController(this.repository)
      : super(AsyncValue.data(repository.currentUser));

  Future<AppUser?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await repository.signIn(email, password);

      if (user == null) {
        throw Exception('Usuario o contraseña incorrectos.');
      }

      final String userRole = user.role.trim().toLowerCase();

      if (userRole == 'admin' || userRole == 'superadmin') {
        state = AsyncValue.data(user);
        return user;
      } else {
        await repository.signOut();
        state = const AsyncValue.data(null);
        throw Exception('No tienes permisos para acceder a este panel.');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await repository.signOut();
      _logger.e('❌ Error en signIn()', error: e, stackTrace: st); 
      rethrow;
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

  /// Actualiza el establecimiento del usuario logueado
  Future<void> updateUserEstablishment(String newEstablishmentId) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    try {
      final updatedUser =
          currentUser.copyWith(establishmentId: newEstablishmentId);

      await _firestore.collection('users').doc(currentUser.id).update({
        'establishmentId': newEstablishmentId,
      });

      state = AsyncData(updatedUser);
    } catch (e, st) {
      _logger.e('⚠️ Error al actualizar establishmentId', error: e, stackTrace: st); 
    }
  }
}
