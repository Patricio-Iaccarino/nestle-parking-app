import 'package:cocheras_nestle_web/features/departments/data/repository/departments_repository.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:flutter_riverpod/legacy.dart';

class DepartmentsState {
  final bool isLoading;
  final String? error;
  final List<Department> departments;

  DepartmentsState({
    this.isLoading = true,
    this.error,
    this.departments = const [],
  });

  DepartmentsState copyWith({
    bool? isLoading,
    String? error,
    List<Department>? departments,
  }) {
    return DepartmentsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      departments: departments ?? this.departments,
    );
  }
}

class DepartmentsController extends StateNotifier<DepartmentsState> {
  final DepartmentsRepository _repository;
  DepartmentsController(this._repository) : super(DepartmentsState());

  Future<void> load(String establishmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getDepartmentsByEstablishment(
        establishmentId,
      );
      state = state.copyWith(departments: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> create(Department department) async {
    try {
      await _repository.createDepartment(department);
      await load(department.establishmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> update(Department department) async {
    try {
      await _repository.updateDepartment(department);
      await load(department.establishmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String id, String establishmentId) async {
    try {
      await _repository.deleteDepartment(id);
      await load(establishmentId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final departmentsControllerProvider =
    StateNotifierProvider<DepartmentsController, DepartmentsState>((ref) {
      final repo = ref.watch(departmentsRepositoryProvider);
      return DepartmentsController(repo);
    });
