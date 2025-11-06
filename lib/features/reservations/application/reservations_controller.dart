// lib/features/reservations/application/reservations_controller.dart
import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:cocheras_nestle_web/features/reservations/data/repository/reservations_repository.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. Un Estado dedicado
class ReservationsState {
  final bool isLoading;
  final String? error;
  final List<SpotRelease> spotReleases;

  ReservationsState({
    this.isLoading = true,
    this.error,
    this.spotReleases = const [],
  });

  ReservationsState copyWith({
    bool? isLoading,
    String? error,
    List<SpotRelease>? spotReleases,
  }) {
    return ReservationsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      spotReleases: spotReleases ?? this.spotReleases,
    );
  }
}

// 2. Un Controller dedicado
class ReservationsController extends StateNotifier<ReservationsState> {
  final ReservationsRepository _repository;

  ReservationsController(this._repository) : super(ReservationsState());

  // Reemplaza el 'loadReservations' del AdminController
  Future<void> load(String establishmentId, {DateTime? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getReservations(establishmentId, date: date);
      state = state.copyWith(spotReleases: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

Future<void> addRelease({
    required String establishmentId,
    required String departmentId,
    required String parkingSpotId,
    required String spotNumber,
    required String releasedByUserId,
    required DateTime releaseDate,
    DateTime? reloadDate, // para refrescar la vista del mismo día
  }) async {
    try {
      await _repository.createRelease(
        establishmentId: establishmentId,
        departmentId: departmentId,
        parkingSpotId: parkingSpotId,
        spotNumber: spotNumber,
        releasedByUserId: releasedByUserId,
        releaseDate: releaseDate,
      );
      await load(establishmentId, date: reloadDate ?? releaseDate);
    } catch (e) {
  print("🔥 ERROR desde addRelease:");
  print(e);    // ✅ imprime link completo si viene desde repo
  state = state.copyWith(error: e.toString());
  rethrow;
    }
  }

  Future<void> reserve({
    required String establishmentId,
    required String releaseId,
    required String bookedByUserId,
    required DateTime dayForReload,
  }) async {
    try {
      await _repository.reserveRelease(
        releaseId: releaseId,
        bookedByUserId: bookedByUserId,
      );
      await load(establishmentId, date: dayForReload);
    } catch (e) {
  print("🔥 ERROR desde reserve:");
  print(e);
  state = state.copyWith(error: e.toString());
  rethrow;
    }
  }

  Future<void> cancel({
    required String establishmentId,
    required String releaseId,
    required DateTime dayForReload,
  }) async {
    try {
      await _repository.cancelReservation(releaseId: releaseId);
      await load(establishmentId, date: dayForReload);
    } catch (e) {
  print("🔥 ERROR desde cancel:");
  print(e);
  state = state.copyWith(error: e.toString());
  rethrow;
    }
  }
}


// 3. El Provider para el Controller
final reservationsControllerProvider =
    StateNotifierProvider<ReservationsController, ReservationsState>((ref) {
  final repo = ref.watch(reservationsRepositoryProvider);
  return ReservationsController(repo);
});