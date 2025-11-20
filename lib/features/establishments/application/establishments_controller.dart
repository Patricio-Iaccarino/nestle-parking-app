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

  // --- 👇 MÉTODOS CRUD MEJORADOS 👇 ---

  Future<void> create(Establishment establishment) async {
    // 1. Guardamos el estado actual por si falla
    final oldState = state;
    // 2. Actualizamos la UI *inmediatamente* (Optimistic Update)
    //    (Podríamos mostrar un loading, pero esto es más rápido)
    try {
      await _repository.createEstablishment(establishment);
      // 3. Recargamos la lista desde cero para tener el ID correcto
      await load(); 
    } catch (e) {
      // 4. Si falla, revertimos al estado anterior y mostramos el error
      state = oldState.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> update(Establishment establishment) async {
    final oldState = state;
    // 1. Actualizamos la UI *inmediatamente*
    final newList = [
      for (final est in state.establishments)
        if (est.id == establishment.id) establishment else est
    ];
    state = state.copyWith(establishments: newList, isLoading: false);

    // 2. Intentamos actualizar en Firestore
    try {
      await _repository.updateEstablishment(establishment);
      // No necesitamos recargar, la UI ya está actualizada.
    } catch (e) {
      // 3. Si falla, revertimos y mostramos error
      state = oldState.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> delete(String id) async {
    final oldState = state;
    // 1. Actualizamos la UI *inmediatamente*
    final newList = state.establishments.where((est) => est.id != id).toList();
    state = state.copyWith(establishments: newList, isLoading: false);

    // 2. Intentamos borrar en Firestore
    try {
      await _repository.deleteEstablishment(id);
      // No necesitamos recargar
    } catch (e) {
      // 3. Si falla, revertimos y mostramos error
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

// 3. El Provider para el Controller (sin cambios)
final establishmentsControllerProvider =
    StateNotifierProvider<EstablishmentsController, EstablishmentsState>((ref) {
  final repo = ref.watch(establishmentsRepositoryProvider);
  return EstablishmentsController(repo);
});