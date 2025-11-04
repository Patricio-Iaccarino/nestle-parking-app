import 'package:cocheras_nestle_web/features/departments/data/repository/departments_repository.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/users/data/repository/users_repository.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/admin/data/repositories/admin_repository.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_repository_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';

class AdminState {
  final bool isLoading;
  final String? error;
  final List<ParkingSpot> parkingSpots;
  final List<AppUser> users;

  AdminState({
    this.isLoading = false,
    this.error,
    this.parkingSpots = const [],
    this.users = const [],
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    List<ParkingSpot>? parkingSpots,
    List<AppUser>? users,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      parkingSpots: parkingSpots ?? this.parkingSpots,
      users: users ?? this.users,
    );
  }
}

class AdminController extends StateNotifier<AdminState> {
  final AdminRepository _repository; // Para 'DashboardSpots'
  final DepartmentsRepository _departmentsRepository;
  final UsersRepository _usersRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AdminController(
    this._repository,
    this._departmentsRepository,
    this._usersRepository,
  ) : super(AdminState());

  // (loadInitialData y todos los métodos de Users están bien)
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) throw Exception('Usuario no autenticado');
      final currentUser = await _usersRepository.getUserProfile(
        firebaseUser.uid,
      );
      final String userRole = currentUser.role.toLowerCase();
      final String userEstId = currentUser.establishmentId;

      Future<List<AppUser>> usersFuture;
      if (userRole == 'superadmin') {
        usersFuture = _usersRepository.getAllUsers();
      } else if (userRole == 'admin') {
        usersFuture = _usersRepository.getUsersForEstablishment(userEstId);
      } else {
        throw Exception('Acceso no autorizado a esta pantalla');
      }

      final results = await Future.wait([usersFuture]);
      final users = results[0];

      List<AppUser> finalUserList;
      if (userRole == 'admin') {
        finalUserList = users
            .where((user) => user.role != 'admin' && user.role != 'superadmin')
            .toList();
      } else {
        finalUserList = users;
      }

      state = state.copyWith(users: finalUserList, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadUsers(String departmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _usersRepository.getUsersByDepartment(departmentId);
      state = state.copyWith(users: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createUser(AppUser user) async {
    state = state.copyWith(isLoading: true);
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

      await _usersRepository.createUser(userWithId);
      await loadInitialData();
    } on FirebaseAuthException catch (e) {
      await loadInitialData();
      if (e.code == 'email-already-in-use') {
        state = state.copyWith(
          error: 'El correo electrónico ya está registrado.',
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          error: 'Error de autenticación: ${e.message}',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await loadInitialData();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      await _usersRepository.updateUser(user);
      await loadInitialData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _usersRepository.deleteUser(id);
      await loadInitialData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> assignAdmin(String userId, String establishmentId) async {
    try {
      await _usersRepository.updateUserRole(
        userId: userId,
        role: 'admin',
        establishmentId: establishmentId,
      );
      state = state.copyWith(isLoading: true);
      await loadUsersForEstablishment(establishmentId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadUsersForEstablishment(String establishmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final departments = await _departmentsRepository
          .getDepartmentsByEstablishment(establishmentId);

      List<AppUser> allUsers = [];
      for (var dept in departments) {
        final users = await _usersRepository.getUsersByDepartment(dept.id);
        allUsers.addAll(users);
      }
      state = state.copyWith(users: allUsers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadUsersForCurrentEstablishment(String establishmentId) async {
    await loadInitialData();
  }

  // --- DASHBOARD ---
  Future<void> loadDashboardData(String establishmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        _repository.getParkingSpotsByEstablishment(establishmentId).then((
          spots,
        ) {
          state = state.copyWith(parkingSpots: spots);
        }),

        loadUsersForEstablishment(establishmentId),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

// --- 👇 CAMBIO 5: El provider ahora inyecta los 4 repositorios ---
final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      final repo = ref.watch(adminRepositoryProvider);
      final departmentsRepo = ref.watch(departmentsRepositoryProvider);
      final usersRepo = ref.watch(usersRepositoryProvider);

      return AdminController(repo, departmentsRepo, usersRepo); // <-- AÑADIDO
    });
