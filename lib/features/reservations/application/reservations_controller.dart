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
}

// 3. El Provider para el Controller
final reservationsControllerProvider =
    StateNotifierProvider<ReservationsController, ReservationsState>((ref) {
  final repo = ref.watch(reservationsRepositoryProvider);
  return ReservationsController(repo);
});