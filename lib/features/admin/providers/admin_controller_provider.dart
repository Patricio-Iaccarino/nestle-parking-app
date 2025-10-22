import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/admin/data/repositories/admin_repository.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_repository_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';

class AdminState {
  final bool isLoading;
  final String? error;
  final List<Establishment> establishments;
  final List<Department> departments;
  final List<ParkingSpot> parkingSpots;
  final List<AppUser> users;
  final List<AppUser> searchResults;
  final List<SpotRelease> spotReleases;

  AdminState({
    this.isLoading = false,
    this.error,
    this.establishments = const [],
    this.departments = const [],
    this.parkingSpots = const [],
    this.users = const [],
    this.searchResults = const [],
    this.spotReleases = const [],
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    List<Establishment>? establishments,
    List<Department>? departments,
    List<ParkingSpot>? parkingSpots,
    List<AppUser>? users,
    List<AppUser>? searchResults,
    List<SpotRelease>? spotReleases,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      establishments: establishments ?? this.establishments,
      departments: departments ?? this.departments,
      parkingSpots: parkingSpots ?? this.parkingSpots,
      users: users ?? this.users,
      searchResults: searchResults ?? this.searchResults,
      spotReleases: spotReleases ?? this.spotReleases,
    );
  }
}

class AdminController extends StateNotifier<AdminState> {
  final AdminRepository _repository;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AdminController(this._repository) : super(AdminState());

  // --- 🔹 ESTABLISHMENTS ---
  Future<void> loadEstablishmentsAndAllUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Cargar establecimientos y usuarios en paralelo para más eficiencia
      final establishmentsFuture = _repository.getAllEstablishments();
      final usersFuture = _repository
          .getAllUsers(); // Asume que este método existe en el repo

      // Esperamos a que ambas consultas terminen
      final results = await Future.wait([establishmentsFuture, usersFuture]);

      // Asignamos los resultados al estado
      final establishments = results[0] as List<Establishment>;
      final users = results[1] as List<AppUser>;

      state = state.copyWith(
        establishments: establishments,
        users: users, // ✨ Guardamos TODOS los usuarios en el estado
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createEstablishment(Establishment establishment) async {
    try {
      await _repository.createEstablishment(establishment);
      await loadEstablishmentsAndAllUsers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateEstablishment(Establishment establishment) async {
    try {
      await _repository.updateEstablishment(establishment);
      await loadEstablishmentsAndAllUsers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteEstablishment(String id) async {
    try {
      await _repository.deleteEstablishment(id);
      await loadEstablishmentsAndAllUsers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // --- 🔹 DEPARTMENTS ---
  Future<void> loadDepartments(String establishmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.getDepartmentsByEstablishment(
        establishmentId,
      );
      state = state.copyWith(departments: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createDepartment(Department department) async {
    try {
      await _repository.createDepartment(department);
      await loadDepartments(department.establishmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateDepartment(Department department) async {
    try {
      await _repository.updateDepartment(department);
      await loadDepartments(department.establishmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteDepartments(String id) async {
    try {
      await _repository.deleteDepartment(id);
      await loadDepartments(
        state.departments.firstWhere((dept) => dept.id == id).establishmentId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // --- 🔹 PARKING SPOTS ---
  Future<void> loadParkingSpots(String departmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.getParkingSpotsByDepartment(
        departmentId,
      );
      state = state.copyWith(parkingSpots: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createParkingSpot(ParkingSpot spot) async {
    try {
      await _repository.createParkingSpot(spot);
      await loadParkingSpots(spot.departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateParkingSpot(ParkingSpot spot) async {
    try {
      await _repository.updateParkingSpot(spot);
      await loadParkingSpots(spot.departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteParkingSpot(String id) async {
    try {
      final spot = state.parkingSpots.firstWhere((spot) => spot.id == id);
      await _repository.deleteParkingSpot(id);
      await loadParkingSpots(spot.departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // --- 🔹 USERS ---
  Future<void> loadUsers(String departmentId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.getUsersByDepartment(departmentId);
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

      await _repository.createUser(userWithId);

      await loadUsers(user.departmentId);
    } on FirebaseAuthException catch (e) {
      // Manejamos errores comunes de Auth, como un email que ya existe
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
      state = state.copyWith(error: e.toString(), isLoading: false);
    } finally {
      // Nos aseguramos de quitar el estado de 'cargando' al final
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      await _repository.updateUser(user);
      await loadUsers(user.departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      final user = state.users.firstWhere((user) => user.id == id);
      await _repository.deleteUser(id);
      await loadUsers(user.departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> assignAdmin(String userId, String establishmentId) async {
    try {
      await _repository.updateUserRole(
        userId: userId,
        role: 'admin',
        establishmentId: establishmentId,
      );
      // Opcional: recargar la lista de usuarios para reflejar el cambio
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
      final departments = await _repository.getDepartmentsByEstablishment(
        establishmentId,
      );
      List<AppUser> allUsers = [];
      for (var dept in departments) {
        final users = await _repository.getUsersByDepartment(dept.id);
        allUsers.addAll(users);
      }
      state = state.copyWith(users: allUsers, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Obtener todos los usuarios
  Future<List<AppUser>> loadAllUsers() async {
    return await _repository.getAllUsers();
  }

  Future<List<AppUser>> getAllTitularUsers() async {
    return await _repository.getAllTitularUsers();
  }

  Future<List<AppUser>> getAllUsers() async {
    return await _repository.getAllUsers();
  }

  // Dentro de la clase AdminController

  Future<void> searchUsers(String query) async {
    state = state.copyWith(isLoading: true, searchResults: []);
    try {
      final q = query.trim().toLowerCase();

      // Si el campo está vacío, limpiamos resultados
      if (q.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      // Obtenemos todos los usuarios desde Firestore
      final allUsers = await _repository.getAllUsers();

      // 🔹 Filtramos solo los que tienen rol "admin" (ya normalizado en AppUser)
      final adminUsers = allUsers.where(
        (user) => user.role.toLowerCase() == 'admin',
      );

      // 🔹 Aplicamos el filtro de búsqueda (por nombre o email)
      final filteredUsers = adminUsers.where((user) {
        final name = user.displayName.toLowerCase();
        final email = user.email.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();

      // Log para debug
      print('🔍 Admins encontrados con "$query": ${filteredUsers.length}');
      for (var u in filteredUsers) {
        print('   → ${u.email} (${u.role})');
      }

      // Actualizamos el estado con los resultados filtrados
      state = state.copyWith(searchResults: filteredUsers, isLoading: false);
    } catch (e) {
      print('❌ ERROR en searchUsers: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
  // --- 🔹 RESERVATIONS ---
  // REEMPLAZA tu método 'loadReservations' con este:
  Future<void> loadReservations(
    String establishmentId, {
    DateTime? date,
  }) async {
    state = state.copyWith(isLoading: true, spotReleases: []);
    try {
      // ✨ ¡MUCHO MÁS LIMPIO!
      // Ahora solo llamamos al repositorio para que haga el trabajo sucio.
      final releases = await _repository.getReservations(
        establishmentId,
        date: date,
      );

      state = state.copyWith(spotReleases: releases, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      final repo = ref.watch(adminRepositoryProvider);
      return AdminController(repo);
    });
