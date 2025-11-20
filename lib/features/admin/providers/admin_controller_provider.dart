import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

class AdminState {
  final bool isLoading;
  final String? error;

  AdminState({this.isLoading = false, this.error});

  AdminState copyWith({bool? isLoading, String? error}) {
    return AdminState(isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class AdminController extends StateNotifier<AdminState> {
  final UsersRepository _usersRepository;

  AdminController(this._usersRepository) : super(AdminState());

  Future<void> createUser(AppUser user) async {
    debugPrint("--- [AdminController] createUser() INICIADO.");
    state = state.copyWith(isLoading: true, error: null);

    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'temporaryRegisterApp',
      options: Firebase.app().options,
    );

    try {
      final tempPassword =
          'temporaryPassword_${DateTime.now().millisecondsSinceEpoch}';

      UserCredential userCredential =
          await FirebaseAuth.instanceFor(
            app: tempApp,
          ).createUserWithEmailAndPassword(
            email: user.email,
            password: tempPassword,
          );

      final newUserId = userCredential.user!.uid;
      await FirebaseAuth.instanceFor(
        app: tempApp,
      ).sendPasswordResetEmail(email: user.email);

      final userWithId = user.copyWith(id: newUserId);

      await _usersRepository.createUser(userWithId);
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      if (e.code == 'email-already-in-use') {
        errorMsg = 'El correo electrónico ya está registrado.';
      } else {
        errorMsg = 'Error de autenticación: ${e.message}';
      }
      state = state.copyWith(error: errorMsg, isLoading: false);
      throw Exception(errorMsg);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
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
      rethrow;
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
      rethrow;
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
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      final usersRepo = ref.watch(usersRepositoryProvider);

      return AdminController(usersRepo);
    });
