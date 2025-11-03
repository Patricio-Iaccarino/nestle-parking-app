import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:cocheras_nestle_web/features/admin/data/repositories/admin_repository.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_repository_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';

class AdminState {
  final bool isLoading;
  final String? error;
  final List<Department> departments;
  final List<ParkingSpot> parkingSpots;
  final List<AppUser> users;
  final List<AppUser> searchResults;
  final List<SpotRelease> spotReleases;

  AdminState({
    this.isLoading = false,
    this.error,
    this.departments = const [],
    this.parkingSpots = const [],
    this.users = const [],
    this.searchResults = const [],
    this.spotReleases = const [],
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    List<Department>? departments,
    List<ParkingSpot>? parkingSpots,
    List<AppUser>? users,
    List<AppUser>? searchResults,
    List<SpotRelease>? spotReleases,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
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

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // --- 1. OBTENER DATOS DEL USUARIO LOGUEADO ---
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) throw Exception('Usuario no autenticado');
      final currentUser = await _repository.getUserProfile(firebaseUser.uid);

      final String userRole = currentUser.role.toLowerCase();
      final String userEstId = currentUser.establishmentId;

      // --- ESTABLISHMENTS YA NO SE CARGA AQUÍ ---

      Future<List<AppUser>> usersFuture;
      Future<List<Department>> departmentsFuture;

      if (userRole == 'superadmin') {
        usersFuture = _repository.getAllUsers();
        departmentsFuture = Future.value(<Department>[]);
      } else if (userRole == 'admin') {
        usersFuture = _repository.getUsersForEstablishment(userEstId);
        departmentsFuture = _repository.getDepartmentsByEstablishment(
          userEstId,
        );
      } else {
        throw Exception('Acceso no autorizado a esta pantalla');
      }

      // --- 3. EJECUTAR CONSULTAS ---
      final results = await Future.wait([
        // establishmentsFuture (BORRADO)
        usersFuture,
        departmentsFuture,
      ]);

      // --- 4. PROCESAR RESULTADOS ---
      // 'results[0]' AHORA ES 'users'
      final users = results[0] as List<AppUser>;
      // 'results[1]' AHORA ES 'departments'
      final departments = results[1] as List<Department>;

      // --- 5. FILTRO DE SEGURIDAD FINAL (en la App) ---
      List<AppUser> finalUserList;
      if (userRole == 'admin') {
        finalUserList = users
            .where((user) => user.role != 'admin' && user.role != 'superadmin')
            .toList();
      } else {
        finalUserList = users;
      }

      // --- 6. ACTUALIZAR ESTADO ---
      state = state.copyWith(
        // establishments: (BORRADO)
        users: finalUserList,
        departments: departments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // --- DEPARTMENTS ---
  // 🚀 MÉTODO 'loadDepartments' ACTUALIZADO (AHORA ES INTELIGENTE)
  Future<void> loadDepartments(String establishmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // --- 1. OBTENER PERFIL DEL USUARIO LOGUEADO ---
      // (Asumo que tienes el método 'getUserProfile' en tu repositorio)
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) throw Exception('Usuario no autenticado');
      final currentUser = await _repository.getUserProfile(firebaseUser.uid);

      final String userRole = currentUser.role.toLowerCase();
      String idParaBuscar;

      // --- 2. DECIDIR QUÉ ID USAR ---
      if (userRole == 'superadmin') {
        // Un SuperAdmin SÍ puede usar el ID que le pasa la UI
        idParaBuscar = establishmentId;
      } else {
        // Un Admin DEBE usar su PROPIO ID. Ignoramos el 'establishmentId'
        // que viene de la UI para cumplir la regla de seguridad.
        idParaBuscar = currentUser.establishmentId;
      }

      // --- 3. CARGAR DATOS ---
      final result = await _repository.getDepartmentsByEstablishment(
        idParaBuscar, // <-- Usamos el ID seguro
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

  // --- PARKING SPOTS ---
  // (Sin cambios en esta sección)
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

  // --- USERS ---

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

      // --- 👇 CAMBIO CLAVE ---
      // Recargamos toda la data inicial. Esto funciona para
      // el Admin (refresca su lista) y para el SuperAdmin (refresca la suya)
      await loadInitialData();
      // ---------------------
    } on FirebaseAuthException catch (e) {
      // Si falla, igual recargamos para que el estado no quede 'colgado'
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
      await loadInitialData(); // Recargamos también en otros errores
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      await _repository.updateUser(user);

      // --- 👇 CAMBIO CLAVE ---
      await loadInitialData();
      // ---------------------
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      // No necesitamos buscar el 'user' en el 'state'
      await _repository.deleteUser(id);

      // --- 👇 CAMBIO CLAVE ---
      await loadInitialData();
      // ---------------------
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

  Future<void> loadUsersForCurrentEstablishment(String establishmentId) async {
    await loadInitialData();
  }

  // --- MÉTODO DE BÚSQUEDA DE ADMINS (YA OPTIMIZADO) ---
  Future<void> searchUsers(String query) async {
    state = state.copyWith(isLoading: true, searchResults: [], error: null);
    try {
      final q = query.trim().toLowerCase();
      final adminUsers = await _repository.getAdminUsers();

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

  // --- RESERVATIONS ---
  // (Sin cambios en esta sección)
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
        loadDepartments(establishmentId),
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

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      final repo = ref.watch(adminRepositoryProvider);
      return AdminController(repo);
    });
