// admin_controller.dart
import 'package:cocheras_nestle_web/features/departments/data/repository/departments_repository.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
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
  final List<AppUser> searchResults;
  final List<SpotRelease> spotReleases;

  AdminState({
    this.isLoading = false,
    this.error,
    this.parkingSpots = const [],
    this.users = const [],
    this.searchResults = const [],
    this.spotReleases = const [],
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    List<ParkingSpot>? parkingSpots,
    List<AppUser>? users,
    List<AppUser>? searchResults,
    List<SpotRelease>? spotReleases,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      parkingSpots: parkingSpots ?? this.parkingSpots,
      users: users ?? this.users,
      searchResults: searchResults ?? this.searchResults,
      spotReleases: spotReleases ?? this.spotReleases,
    );
  }
}

class AdminController extends StateNotifier<AdminState> {
  // --- 👇 CAMBIO 2: Añadimos el nuevo repositorio ---
  final AdminRepository _repository; // Para 'Reservations' y 'DashboardSpots'
  final DepartmentsRepository _departmentsRepository;
  final UsersRepository _usersRepository; // Para todo lo de 'Users'
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AdminController(
    this._repository,
    this._departmentsRepository,
    this._usersRepository,
  ) : super(AdminState());

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) throw Exception('Usuario no autenticado');
      
      final currentUser = await _usersRepository.getUserProfile(firebaseUser.uid); 
      final String userRole = currentUser.role.toLowerCase();
      final String userEstId = currentUser.establishmentId;

      Future<List<AppUser>> usersFuture;
      if (userRole == 'superadmin') {
        usersFuture = _usersRepository.getAllUsers(); // <-- CAMBIADO
      } else if (userRole == 'admin') {
        usersFuture = _usersRepository.getUsersForEstablishment(userEstId); // <-- CAMBIADO
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

      state = state.copyWith(
        users: finalUserList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadUsers(String departmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _usersRepository.getUsersByDepartment(departmentId); // <-- CAMBIADO
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

      await _usersRepository.createUser(userWithId); // <-- CAMBIADO
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
      await _usersRepository.updateUser(user); // <-- CAMBIADO
      await loadInitialData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _usersRepository.deleteUser(id); // <-- CAMBIADO
      await loadInitialData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> assignAdmin(String userId, String establishmentId) async {
    try {
      await _usersRepository.updateUserRole( // <-- CAMBIADO
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
      // Este usa _departmentsRepository (¡correcto!)
      final departments = await _departmentsRepository
          .getDepartmentsByEstablishment(establishmentId);
          
      List<AppUser> allUsers = [];
      for (var dept in departments) {
        final users = await _usersRepository.getUsersByDepartment(dept.id); // <-- CAMBIADO
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

  Future<void> searchUsers(String query) async {
    state = state.copyWith(isLoading: true, searchResults: [], error: null);
    try {
      final q = query.trim().toLowerCase();
      final adminUsers = await _usersRepository.getAdminUsers(); // <-- CAMBIADO

      List<AppUser> filteredUsers;
      if (q.isEmpty) {
        filteredUsers = adminUsers;
      } else {
        filteredUsers = adminUsers.where((user) {
          final name = user.displayName.toLowerCase();
          final email = user.email.toLowerCase();
          return name.contains(q) || email.contains(q);
        }).toList();
      }
      state = state.copyWith(searchResults: filteredUsers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> loadInitialAssignableUsers() async {
    await searchUsers('');
  }

  Future<void> loadReservations(
    String establishmentId, {
    DateTime? date,
  }) async {
    state = state.copyWith(isLoading: true, spotReleases: []);
    try {
      final releases = await _repository.getReservations(
        establishmentId,
        date: date,
      );
      state = state.copyWith(spotReleases: releases, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadDashboardData(String establishmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        _repository.getParkingSpotsByEstablishment(establishmentId).then((
          spots,
        ) {
          state = state.copyWith(parkingSpots: spots);
        }),
        loadReservations(establishmentId, date: DateTime.now()),
        loadUsersForEstablishment(establishmentId),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final adminControllerProvider = StateNotifierProvider<AdminController, AdminState>((
  ref,
) {

  final repo = ref.watch(adminRepositoryProvider);
  final departmentsRepo = ref.watch(departmentsRepositoryProvider);
  final usersRepo = ref.watch(usersRepositoryProvider); // 1. Míralo
  
  return AdminController(repo, departmentsRepo, usersRepo); // 2. Pásalo
});