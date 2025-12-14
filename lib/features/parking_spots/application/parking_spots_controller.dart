import 'package:cocheras_nestle_web/features/parking_spots/data/repository/parking_spots_repository.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:flutter_riverpod/legacy.dart';

class ParkingSpotsState {
  final bool isLoading;
  final String? error;
  final List<ParkingSpot> parkingSpots;

  ParkingSpotsState({
    this.isLoading = true,
    this.error,
    this.parkingSpots = const [],
  });

  ParkingSpotsState copyWith({
    bool? isLoading,
    String? error,
    List<ParkingSpot>? parkingSpots,
  }) {
    return ParkingSpotsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      parkingSpots: parkingSpots ?? this.parkingSpots,
    );
  }
}

class ParkingSpotsController extends StateNotifier<ParkingSpotsState> {
  final ParkingSpotsRepository _repository;
  ParkingSpotsController(this._repository) : super(ParkingSpotsState());

  Future<void> load(String departmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result =
          await _repository.getParkingSpotsByDepartment(departmentId);
      state = state.copyWith(parkingSpots: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadByEstablishment(String establishmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result =
          await _repository.getParkingSpotsByEstablishment(establishmentId);
      state = state.copyWith(parkingSpots: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // 🔹 CREATE con validación de duplicados
  Future<void> create(ParkingSpot spot) async {
    try {
      // 1) Validar que no exista cochera duplicada (mismo número + piso + establecimiento)
      final exists = state.parkingSpots.any((s) =>
          s.establishmentId == spot.establishmentId &&
          s.floor == spot.floor &&
          s.spotNumber.trim().toLowerCase() ==
              spot.spotNumber.trim().toLowerCase());

      if (exists) {
        state = state.copyWith(
          error:
              'Ya existe una cochera con el número ${spot.spotNumber} en el piso ${spot.floor} para este establecimiento.',
        );
        return; // no creamos nada
      }

      // 2) Lógica normal (incluye tu validación de límite en el repositorio)
      await _repository.createParkingSpot(spot);
      await load(spot.departmentId); // recarga lista como ya lo tenías
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // 🔹 UPDATE con validación de duplicados
  Future<void> update(ParkingSpot spot) async {
    try {
      // 1) Validar que no choque con OTRA cochera
      final exists = state.parkingSpots.any((s) =>
          s.id != spot.id && // distinta cochera
          s.establishmentId == spot.establishmentId &&
          s.floor == spot.floor &&
          s.spotNumber.trim().toLowerCase() ==
              spot.spotNumber.trim().toLowerCase());

      if (exists) {
        state = state.copyWith(
          error:
              'Ya existe otra cochera con el número ${spot.spotNumber} en el piso ${spot.floor} para este establecimiento.',
        );
        return; // no actualizamos
      }

      // 2) Actualización normal
      await _repository.updateParkingSpot(spot);
      await load(spot.departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String id, String departmentId) async {
    try {
      await _repository.deleteParkingSpot(id);
      await load(departmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}


final parkingSpotsControllerProvider =
    StateNotifierProvider<ParkingSpotsController, ParkingSpotsState>((ref) {
  final repo = ref.watch(parkingSpotsRepositoryProvider);
  return ParkingSpotsController(repo);
});
