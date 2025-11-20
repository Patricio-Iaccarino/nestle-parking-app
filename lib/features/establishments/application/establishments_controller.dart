import 'package:cocheras_nestle_web/features/establishments/data/establishments_repository.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:flutter_riverpod/legacy.dart';

class EstablishmentsState {
  final bool isLoading;
  final String? error;
  final List<Establishment> establishments;

  EstablishmentsState({
    this.isLoading = true,
    this.error,
    this.establishments = const [],
  });

  EstablishmentsState copyWith({
    bool? isLoading,
    String? error,
    List<Establishment>? establishments,
  }) {
    return EstablishmentsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      establishments: establishments ?? this.establishments,
    );
  }
}

class EstablishmentsController extends StateNotifier<EstablishmentsState> {
  final EstablishmentsRepository _repository;

  EstablishmentsController(this._repository) : super(EstablishmentsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getAllEstablishments();
      state = state.copyWith(establishments: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> create(Establishment establishment) async {
    final oldState = state;
    try {
      await _repository.createEstablishment(establishment);
      await load();
    } catch (e) {
      state = oldState.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> update(Establishment establishment) async {
    final oldState = state;
    final newList = [
      for (final est in state.establishments)
        if (est.id == establishment.id) establishment else est,
    ];
    state = state.copyWith(establishments: newList, isLoading: false);

    try {
      await _repository.updateEstablishment(establishment);
    } catch (e) {
      state = oldState.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> delete(String id) async {
    final oldState = state;
    final newList = state.establishments.where((est) => est.id != id).toList();
    state = state.copyWith(establishments: newList, isLoading: false);

    try {
      await _repository.deleteEstablishment(id);
    } catch (e) {
      state = oldState.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Establishment? getEstablishmentById(String id) {
    try {
      return state.establishments.firstWhere((est) => est.id == id);
    } catch (e) {
      return null;
    }
  }
}

final establishmentsControllerProvider =
    StateNotifierProvider<EstablishmentsController, EstablishmentsState>((ref) {
      final repo = ref.watch(establishmentsRepositoryProvider);
      return EstablishmentsController(repo);
    });
