// lib/features/admin/presentation/controllers/admin_users_controller.dart
import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. Un Estado dedicado solo para la lista de Admins
class AdminUsersState {
  final bool isLoading;
  final String? error;
  final List<AppUser> adminUsers;

  AdminUsersState({
    this.isLoading = true,
    this.error,
    this.adminUsers = const [],
  });

  AdminUsersState copyWith({
    bool? isLoading,
    String? error,
    List<AppUser>? adminUsers,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      adminUsers: adminUsers ?? this.adminUsers,
    );
  }
}

// 2. Un Controller dedicado
class AdminUsersController extends StateNotifier<AdminUsersState> {
  final UsersRepository _usersRepository;

  AdminUsersController(this._usersRepository) : super(AdminUsersState()) {
    // Carga los admins automáticamente cuando se usa el provider
    load();
  }

  // --- ESTE ES EL MÉTODO 'load()' ---
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Llama al método del repo que trae SOLO los admins
      final result = await _usersRepository.getAdminUsers();
      state = state.copyWith(adminUsers: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// 3. El Provider para el Controller
final adminUsersControllerProvider =
    StateNotifierProvider<AdminUsersController, AdminUsersState>((ref) {
  final repo = ref.watch(usersRepositoryProvider);
  return AdminUsersController(repo);
});