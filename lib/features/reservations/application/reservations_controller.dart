import 'package:cocheras_nestle_web/features/parking_spots/domain/models/spot_release_model.dart';
import 'package:cocheras_nestle_web/features/reservations/data/repository/reservations_repository.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logger/logger.dart';
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

class ReservationsController extends StateNotifier<ReservationsState> {
  final ReservationsRepository _repository;
  final Logger _logger = Logger(); 

  ReservationsController(this._repository) : super(ReservationsState());

  Future<void> load(String establishmentId, {DateTime? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getReservations(establishmentId, date: date);
      state = state.copyWith(spotReleases: result, isLoading: false);
    } catch (e) {
      _logger.e("Error cargando reservas", error: e);
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
    DateTime? reloadDate, 
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
    } catch (e, stack) {
      _logger.e("ERROR desde addRelease()", error: e, stackTrace: stack);
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
    } catch (e, stack) {
      _logger.e("ERROR desde reserve()", error: e, stackTrace: stack);
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
    } catch (e, stack) {
      _logger.e("ERROR desde cancel()", error: e, stackTrace: stack);
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
  /// 🔹 NUEVO: liberar cochera por un RANGO de fechas (inclusive)
  Future<void> addReleaseRange({
    required String establishmentId,
    required String departmentId,
    required String parkingSpotId,
    required String spotNumber,
    required String releasedByUserId,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? reloadDate,
  }) async {
    try {
      await _repository.createReleaseRange(
        establishmentId: establishmentId,
        departmentId: departmentId,
        parkingSpotId: parkingSpotId,
        spotNumber: spotNumber,
        releasedByUserId: releasedByUserId,
        startDate: startDate,
        endDate: endDate,
      );

      // Recargamos la vista en el día que tengas seleccionado
      await load(
        establishmentId,
        date: reloadDate ?? startDate,
      );
    } catch (e, stack) {
      _logger.e("ERROR desde addReleaseRange()", error: e, stackTrace: stack);
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  
}



final reservationsControllerProvider =
    StateNotifierProvider<ReservationsController, ReservationsState>((ref) {
  final repo = ref.watch(reservationsRepositoryProvider);
  return ReservationsController(repo);
});
