// lib/features/users/presentation/users_controller.dart
import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. Un Estado dedicado solo para Usuarios
class UsersState {
  final bool isLoading;
  final String? error;
  final List<AppUser> users;

  UsersState({
    this.isLoading = true,
    this.error,
    this.users = const [],
  });

  UsersState copyWith({
    bool? isLoading,
    String? error,
    List<AppUser>? users,
  }) {
    return UsersState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      users: users ?? this.users,
    );
  }
}

// 2. Un Controller dedicado
class UsersController extends StateNotifier<UsersState> {
  final UsersRepository _usersRepository;

  UsersController(this._usersRepository) : super(UsersState());

  // Carga usuarios de un solo departamento (para la 'UsersScreen')
  Future<void> loadUsersByDepartment(String departmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _usersRepository.getUsersByDepartment(departmentId);
      state = state.copyWith(users: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Carga TODOS los usuarios (Titulares, Suplentes, etc.) de un establecimiento
  // (para la 'GlobalUsersScreen')
  Future<void> loadUsersByEstablishment(String establishmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _usersRepository.getUsersForEstablishment(establishmentId);
      
      // Filtramos para que el Admin no vea a otros Admins o SuperAdmins
      final filteredList = result.where((user) => 
          user.role.toLowerCase() != 'superadmin' &&
          user.role.toLowerCase() != 'admin'
      ).toList();

      state = state.copyWith(users: filteredList, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// 3. El Provider para el Controller
final usersControllerProvider =
    StateNotifierProvider<UsersController, UsersState>((ref) {
  // Este provider ahora usa el UsersRepository
  final repo = ref.watch(usersRepositoryProvider);
  return UsersController(repo);
});