import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  
import 'package:cocheras_nestle_web/features/vehicles/data/vehicles_repository.dart';
import 'package:cocheras_nestle_web/features/vehicles/domain/vehicle_model.dart';

class VehiclesState {
  final bool isLoading;
  final String? error;
  final List<Vehicle> vehicles;

  const VehiclesState({
    this.isLoading = true,
    this.error,
    this.vehicles = const [],
  });

  VehiclesState copyWith({
    bool? isLoading,
    String? error,
    List<Vehicle>? vehicles,
  }) {
    return VehiclesState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      vehicles: vehicles ?? this.vehicles,
    );
  }
}

/// Provider del repositorio (si aún no lo tenés así, ajustalo al path real)
final vehiclesRepositoryProvider = Provider<VehiclesRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return VehiclesRepository(firestore);   // acá le pasamos el arg
});

/// Provider del controller usando la API nueva de Riverpod
final vehiclesControllerProvider =
    NotifierProvider<VehiclesController, VehiclesState>(
  VehiclesController.new,
);

class VehiclesController extends Notifier<VehiclesState> {
  late VehiclesRepository _repository;

  @override
  VehiclesState build() {
    _repository = ref.read(vehiclesRepositoryProvider);

    // Estado inicial
    final initialState = const VehiclesState(
      isLoading: true,
      vehicles: [],
    );

    // Disparar carga inicial
    Future.microtask(load);

    return initialState;
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getAllVehicles();
      state = state.copyWith(
        vehicles: result,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
}
