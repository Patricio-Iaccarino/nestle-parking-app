
import 'package:cocheras_nestle_web/features/parking_spots/data/repository/parking_spots_repository.dart';
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/parking_spot_model.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. Estado para ParkingSpots
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

// 2. Controller para ParkingSpots
class ParkingSpotsController extends StateNotifier<ParkingSpotsState> {
  final ParkingSpotsRepository _repository;
  ParkingSpotsController(this._repository) : super(ParkingSpotsState());

  Future<void> load(String departmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getParkingSpotsByDepartment(departmentId);
      state = state.copyWith(parkingSpots: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadByEstablishment(String establishmentId) async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final result = await _repository.getParkingSpotsByEstablishment(establishmentId);
    state = state.copyWith(parkingSpots: result, isLoading: false);
  } catch (e) {
    state = state.copyWith(error: e.toString(), isLoading: false);
  }
}



  Future<void> create(ParkingSpot spot) async {
    try {
      await _repository.createParkingSpot(spot);
      await load(spot.departmentId); // Recarga la lista
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> update(ParkingSpot spot) async {
    try {
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

// 3. El Provider para el Controller
final parkingSpotsControllerProvider =
    StateNotifierProvider<ParkingSpotsController, ParkingSpotsState>((ref) {
  final repo = ref.watch(parkingSpotsRepositoryProvider);
  return ParkingSpotsController(repo);
});