import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';

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

class AdminUsersController extends StateNotifier<AdminUsersState> {
  final UsersRepository _usersRepository;

  AdminUsersController(this._usersRepository) : super(AdminUsersState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _usersRepository.getAdminUsers();
      state = state.copyWith(adminUsers: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final adminUsersControllerProvider =
    StateNotifierProvider<AdminUsersController, AdminUsersState>((ref) {
      final repo = ref.watch(usersRepositoryProvider);
      return AdminUsersController(repo);
    });
