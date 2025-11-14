// lib/features/admin/providers/admin_controller.dart
import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<void> createUser(AppUser user) async {
    ("--- [AdminController] createUser() INICIADO.");
    state = state.copyWith(isLoading: true, error: null); // Inicia la carga
    try {
      final tempPassword =
          'temporaryPassword_${DateTime.now().millisecondsSinceEpoch}';
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: user.email,
            password: tempPassword,
          );
      final newUserId = userCredential.user!.uid;
      await _auth.sendPasswordResetEmail(email: user.email);
      final userWithId = user.copyWith(id: newUserId);

      ("--- [AdminController] createUser: Usuario creado en Auth. Llamando a repo de Firestore...");
      await _usersRepository.createUser(userWithId);
      ("--- [AdminController] createUser: Usuario creado en Firestore.");
      
    } on FirebaseAuthException catch (e) {
      ("--- [AdminController] ❗️ ERROR de FirebaseAuth en createUser: ${e.message}");
      String errorMsg;
      if (e.code == 'email-already-in-use') {
        errorMsg = 'El correo electrónico ya está registrado.';
      } else {
        errorMsg = 'Error de autenticación: ${e.message}';
      }
      state = state.copyWith(error: errorMsg, isLoading: false);
      throw Exception(errorMsg); 

    } catch (e) {
      ("--- [AdminController] ❗️ ERROR genérico en createUser: $e");
      state = state.copyWith(error: e.toString(), isLoading: false);
      throw e;
    } finally {
      state = state.copyWith(isLoading: false); // Termina la carga
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