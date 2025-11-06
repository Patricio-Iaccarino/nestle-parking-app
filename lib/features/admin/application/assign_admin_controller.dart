import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. Un Estado dedicado
class AssignAdminState {
  final bool isLoading;
  final String? error;
  final List<AppUser> assignableAdmins;

  AssignAdminState({
    this.isLoading = false,
    this.error,
    this.assignableAdmins = const [],
  });

  AssignAdminState copyWith({
    bool? isLoading,
    String? error,
    List<AppUser>? assignableAdmins,
  }) {
    return AssignAdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      assignableAdmins: assignableAdmins ?? this.assignableAdmins,
    );
  }
}

// 2. Un Controller dedicado
class AssignAdminController extends StateNotifier<AssignAdminState> {
  final UsersRepository _usersRepository;
  List<AppUser> _allAdminsCache = []; // Caché simple para evitar lecturas de DB

  AssignAdminController(this._usersRepository) : super(AssignAdminState());

  // Reemplaza el 'searchUsers' del AdminController
  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // OptimizaciÃ³n: si el caché estÃ¡ vacÃ­o, llÃ©nalo
      if (_allAdminsCache.isEmpty) {
        _allAdminsCache = await _usersRepository.getAdminUsers();
      }

      final q = query.trim().toLowerCase();
      List<AppUser> filteredUsers;

      if (q.isEmpty) {
        filteredUsers = _allAdminsCache;
      } else {
        filteredUsers = _allAdminsCache.where((user) {
          final name = user.displayName.toLowerCase();
          final email = user.email.toLowerCase();
          return name.contains(q) || email.contains(q);
        }).toList();
      }

      state = state.copyWith(assignableAdmins: filteredUsers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // MÃ©todo para la carga inicial
  Future<void> loadInitialAdmins() async {
    await search('');
  }
}

// 3. El Provider para el Controller
final assignAdminControllerProvider =
    StateNotifierProvider<AssignAdminController, AssignAdminState>((ref) {
      final repo = ref.watch(usersRepositoryProvider);
      return AssignAdminController(repo);
    });
