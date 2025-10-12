import 'package:cocheras_nestle_web/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/auth/domain/models/app_user.dart';
import 'package:flutter_riverpod/legacy.dart';

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

  AuthController(this.repository)
      : super(AsyncValue.data(repository.currentUser));

  Future<AppUser?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await repository.signIn(email, password);
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // para que LoginForm capture errores
    }
  }

  Future<void> signOut() async {
    await repository.signOut();
    state = const AsyncValue.data(null);
  }

 

}
