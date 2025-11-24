import 'package:cocheras_nestle_web/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

// --- 👇 IMPORTAR EL REPOSITORIO DE USUARIOS ---
import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  // --- 👇 CAMBIO 1: Inyectamos también el UsersRepository ---
  final usersRepo = ref.watch(usersRepositoryProvider);
  return AuthController(authRepo, usersRepo);
});

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository repository;
  // --- 👇 CAMBIO 2: Añadimos la variable del repositorio ---
  final UsersRepository _usersRepository;
  
  final _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // --- 👇 CAMBIO 3: Actualizamos el Constructor ---
  AuthController(this.repository, this._usersRepository)
      : super(const AsyncValue.loading()) {
    // Al iniciar el controlador (ej. al dar F5), verificamos la sesión
    _checkAuthStatus();
  }

  // --- 👇 CAMBIO 4: El método mágico para persistir la sesión ---
  Future<void> _checkAuthStatus() async {
    state = const AsyncValue.loading();
    try {
      // 1. Preguntamos al repo si hay un usuario "crudo" de Firebase en memoria
      final firebaseUser = repository.firebaseUser; // (El getter que agregamos en el paso 1)

      if (firebaseUser != null) {
        // 2. Si hay usuario, buscamos sus datos completos (Rol, Sede) en Firestore
        final appUser = await _usersRepository.getUserProfile(firebaseUser.uid);
        
        // 3. Verificamos permisos (opcional, pero recomendado)
        final String userRole = appUser.role.trim().toLowerCase();
        if (userRole == 'admin' || userRole == 'superadmin') {
           state = AsyncValue.data(appUser);
        } else {
           await repository.signOut();
           state = const AsyncValue.data(null);
        }
      } else {
        // 3. Si no hay usuario, el estado es null (Login)
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      // Si falla (ej: borraron el usuario de la DB), cerramos sesión
      await repository.signOut();
      state = AsyncValue.error(e, st);
    }
  }

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