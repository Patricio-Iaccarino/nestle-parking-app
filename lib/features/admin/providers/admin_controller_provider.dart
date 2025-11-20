// lib/features/admin/providers/admin_controller.dart
import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';


// --- 👇 ESTADO FINAL Y LIMPIO 👇 ---
class AdminState {
  final bool isLoading;
  final String? error;

  AdminState({
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// --- 👇 CONTROLADOR FINAL Y LIMPIO (Solo Acciones) 👇 ---
class AdminController extends StateNotifier<AdminState> {
  // (Solo mantenemos los repos que usan los métodos CRUD)
  final UsersRepository _usersRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AdminController(
    this._usersRepository,
  ) : super(AdminState());

  // --- 👇 MÉTODOS DE LECTURA (load) ELIMINADOS 👇 ---
  // loadInitialData() -> ELIMINADO
  // loadUsers() -> ELIMINADO
  // loadUsersForEstablishment() -> ELIMINADO
  // loadDashboardData() -> ELIMINADO
  // loadReservations() -> ELIMINADO
  // searchUsers() -> ELIMINADO
  // loadInitialAssignableUsers() -> ELIMINADO
  // --------------------------------------------------

  // --- 👇 MÉTODOS CRUD (Ahora solo ejecutan la acción) 👇 ---
  // Asegúrate de agregar este import arriba:
  // import 'package:firebase_core/firebase_core.dart';

  Future<void> createUser(AppUser user) async {
    debugPrint("--- [AdminController] createUser() INICIADO.");
    state = state.copyWith(isLoading: true, error: null);

    // 1. Creamos una instancia temporal de la App de Firebase
    // Esto nos permite interactuar con Auth sin afectar la sesión principal
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'temporaryRegisterApp',
      options: Firebase.app().options,
    );

    try {
      final tempPassword =
          'temporaryPassword_${DateTime.now().millisecondsSinceEpoch}';
      
      // 2. Usamos la instancia temporal para crear el usuario
      // Nota: Usamos instanceFor(app: tempApp) en lugar de _auth
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
            email: user.email,
            password: tempPassword,
          );

      final newUserId = userCredential.user!.uid;
      
      // 3. Enviamos el email (esto sí lo podemos hacer con la instancia principal o la temp)
      // Usamos la temp para ser consistentes con el usuario recién creado
      await FirebaseAuth.instanceFor(app: tempApp)
          .sendPasswordResetEmail(email: user.email);
      
      final userWithId = user.copyWith(id: newUserId);

      debugPrint("--- [AdminController] createUser: Usuario creado en Auth (Temp). ID: $newUserId");
      debugPrint("--- [AdminController] Sesión actual (Main): ${_auth.currentUser?.email}"); // Debería seguir siendo el SuperAdmin

      // 4. Escribimos en Firestore usando el repositorio (que usa la instancia PRINCIPAL)
      // Como no se cerró la sesión, aquí sigues siendo SuperAdmin, así que las reglas te dejarán pasar.
      await _usersRepository.createUser(userWithId);
      
      debugPrint("--- [AdminController] createUser: Usuario guardado en Firestore exitosamente.");
      
    } on FirebaseAuthException catch (e) {
      debugPrint("--- [AdminController] ❗️ ERROR de FirebaseAuth: ${e.message}");
      String errorMsg;
      if (e.code == 'email-already-in-use') {
        errorMsg = 'El correo electrónico ya está registrado.';
      } else {
        errorMsg = 'Error de autenticación: ${e.message}';
      }
      state = state.copyWith(error: errorMsg, isLoading: false);
      throw Exception(errorMsg); 

    } catch (e) {
      debugPrint("--- [AdminController] ❗️ ERROR genérico: $e");
      state = state.copyWith(error: e.toString(), isLoading: false);
      throw e;
    } finally {
      // 5. MUY IMPORTANTE: Borrar la app temporal para liberar memoria
      await tempApp.delete();
      state = state.copyWith(isLoading: false);
    }
  }
  Future<void> updateUser(AppUser user) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _usersRepository.updateUser(user);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      throw e;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteUser(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _usersRepository.deleteUser(id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      throw e;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> assignAdmin(String userId, String establishmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _usersRepository.updateUserRole(
        userId: userId,
        role: 'admin',
        establishmentId: establishmentId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      throw e;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

// --- 👇 Provider final (solo inyecta UsersRepository) 👇 ---
final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      
  final usersRepo = ref.watch(usersRepositoryProvider);

  return AdminController(usersRepo);
});