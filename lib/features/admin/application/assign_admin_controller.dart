import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter_riverpod/legacy.dart';

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

class AssignAdminController extends StateNotifier<AssignAdminState> {
  final UsersRepository _usersRepository;
  List<AppUser> _allAdminsCache = [];

  AssignAdminController(this._usersRepository) : super(AssignAdminState());

  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
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

  Future<void> loadInitialAdmins() async {
    await search('');
  }
}

final assignAdminControllerProvider =
    StateNotifierProvider<AssignAdminController, AssignAdminState>((ref) {
      final repo = ref.watch(usersRepositoryProvider);
      return AssignAdminController(repo);
    });
