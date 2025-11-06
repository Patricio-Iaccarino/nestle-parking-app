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
    // 1. El repositorio loguea al usuario y trae su perfil de Firestore.
    // (Ahora sabemos que esto ya no crea usuarios 'user' por error).
    final user = await repository.signIn(email, password);

    // 2. Si el repo devuelve null (error en repo) o el usuario es null.
    if (user == null) {
      throw Exception('Usuario o contraseña incorrectos.');
    }

    // --- 👇 ¡AQUÍ VA LA VALIDACIÓN DE ROL! 👇 ---

    // 3. Limpiamos el rol para evitar errores de espacios o mayúsculas
    final String userRole = user.role.trim().toLowerCase();

    // 4. Comprobamos si tiene permiso
    if (userRole == 'admin' || userRole == 'superadmin') {
      // --- ÉXITO ---
      // El rol es correcto, lo guardamos en el estado y lo dejamos entrar.
      state = AsyncValue.data(user);
      return user;
    } else {
      // --- FALLO POR PERMISOS ---
      // El usuario existe (ej. es 'TITULAR') pero no es admin.
      // Lo echamos.
      await repository.signOut(); // Cerramos la sesión de Firebase Auth
      state = const AsyncValue.data(null); // Reseteamos el estado
      
      // Lanzamos el error que verá el usuario en el formulario
      throw Exception('No tienes permisos para acceder a este panel.');
    }
    // --------------------------------------------------

  } catch (e, st) {
    // 5. Capturamos CUALQUIER error
    // (sea 'Usuario incorrecto' o 'No tienes permisos')
    state = AsyncValue.error(e, st);
    
    // Nos aseguramos de que esté deslogueado si hubo un error
    await repository.signOut(); 
    
    rethrow; // Re-lanzamos el error para que el formulario (LoginForm) lo muestre
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
