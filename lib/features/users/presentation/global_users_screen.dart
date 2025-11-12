import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';

class GlobalUsersScreen extends ConsumerStatefulWidget {
  const GlobalUsersScreen({super.key});

  @override
  ConsumerState<GlobalUsersScreen> createState() => _GlobalUsersScreenState();
}

class _GlobalUsersScreenState extends ConsumerState<GlobalUsersScreen> {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final establishmentId =
          ref.read(authControllerProvider).value?.establishmentId;
      if (establishmentId == null) return;

      ref
          .read(adminControllerProvider.notifier)
          .loadDashboardData(establishmentId);
      ref.read(departmentsControllerProvider.notifier).load(establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminControllerProvider);
    final adminController = ref.read(adminControllerProvider.notifier);
    final departmentState = ref.watch(departmentsControllerProvider);

    final bool isLoading = adminState.isLoading || departmentState.isLoading;
    final String? error = adminState.error ?? departmentState.error;

    final users = adminState.users.where((u) {
      final q = searchQuery.toLowerCase();
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    final departments = departmentState.departments;
    final parkingSpots = adminState.parkingSpots;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Establecimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final establishmentId =
                  ref.read(authControllerProvider).value?.establishmentId;
              if (establishmentId == null) return;
              ref
                  .read(adminControllerProvider.notifier)
                  .loadDashboardData(establishmentId);
              ref
                  .read(departmentsControllerProvider.notifier)
                  .load(establishmentId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Usuario',
            onPressed: () =>
                _showCreateUserDialog(context, adminController, departments),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar usuario...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (q) => setState(() => searchQuery = q),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(
                        child: Text(error ?? 'No hay usuarios registrados.'),
                      )
                    : PaginatedDataTable2(
                        columns: const [
                          DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                          DataColumn2(label: Text('Email'), size: ColumnSize.L),
                          DataColumn2(label: Text('Rol'), size: ColumnSize.S),
                          DataColumn2(
                              label: Text('Departamento'),
                              size: ColumnSize.M),
                          DataColumn2(label: Text('Cochera'), size: ColumnSize.S),
                          DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
                        ],
                        empty: Center(
                          child: Text(error ?? 'No se encontraron usuarios.'),
                        ),
                        rowsPerPage: 20,
                        availableRowsPerPage: const [10, 20, 50],
                        minWidth: 1000,
                        showFirstLastButtons: true,
                        wrapInCard: false,
                        source: _UsersDataSource(
                          users: users,
                          departments: departments,
                          parkingSpots: parkingSpots,
                          onEdit: (user) =>
                              _showEditDialog(context, adminController, user),
                          onDelete: (userId) =>
                              _confirmDelete(context, adminController, userId),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // CONFIRMAR ELIMINAR USUARIO
  // ───────────────────────────────────────────────
  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller,
    String userId,
  ) async {
    bool isDeleting = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Eliminar usuario'),
            content: isDeleting
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Eliminando usuario...'),
                    ],
                  )
                : const Text('¿Estás seguro de eliminar este usuario?'),
            actions: isDeleting
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () async {
                        setState(() => isDeleting = true);
                        await controller.deleteUser(userId);
                        final estId = ref
                            .read(authControllerProvider)
                            .value
                            ?.establishmentId;
                        if (estId != null) {
                          await ref
                              .read(adminControllerProvider.notifier)
                              .loadDashboardData(estId);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────
  // CREAR USUARIO
  // ───────────────────────────────────────────────
  Future<void> _showCreateUserDialog(
    BuildContext context,
    AdminController controller,
    List<Department> departments,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'TITULAR';
    String? selectedDepartmentId;
    bool isSaving = false;
    final authUser = ref.read(authControllerProvider).value;
    final currentEstablishmentId = authUser?.establishmentId ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuevo Usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: const [
                        DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                        DropdownMenuItem(
                            value: 'SUPLENTE', child: Text('Suplente')),
                      ],
                      onChanged: (val) =>
                          setState(() => selectedRole = val ?? 'TITULAR'),
                    ),
                    const SizedBox(height: 8),
                    if (selectedRole == 'TITULAR' || selectedRole == 'SUPLENTE')
                      DropdownButtonFormField<String>(
                        initialValue: selectedDepartmentId,
                        decoration: const InputDecoration(labelText: 'Departamento'),
                        items: departments
                            .map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedDepartmentId = val),
                      ),
                    if (isSaving) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              emailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Complete todos los campos obligatorios')),
                            );
                            return;
                          }

                          setState(() => isSaving = true);

                          final newUser = AppUser(
                            id: '',
                            email: emailController.text.trim(),
                            displayName: nameController.text.trim(),
                            role: selectedRole,
                            establishmentId: currentEstablishmentId,
                            establishmentName: '',
                            vehiclePlates: const [],
                            departmentId: (selectedRole == 'TITULAR' ||
                                    selectedRole == 'SUPLENTE')
                                ? (selectedDepartmentId ?? '')
                                : '',
                          );

                          await controller.createUser(newUser);
                          final estId = ref
                              .read(authControllerProvider)
                              .value
                              ?.establishmentId;
                          if (estId != null) {
                            await ref
                                .read(adminControllerProvider.notifier)
                                .loadDashboardData(estId);
                          }

                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────
  // EDITAR USUARIO
  // ───────────────────────────────────────────────
  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = user.role;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Usuario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !isSaving,
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    enabled: !isSaving,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                      DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                    ],
                    onChanged:
                        isSaving ? null : (val) => selectedRole = val ?? user.role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                  ),
                  if (isSaving) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ]
                ],
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);

                          final updated = user.copyWith(
                            displayName: nameController.text.trim(),
                            email: emailController.text.trim(),
                            role: selectedRole,
                          );

                          await controller.updateUser(updated);
                          final estId =
                              ref.read(authControllerProvider).value?.establishmentId;
                          if (estId != null) {
                            await ref
                                .read(adminControllerProvider.notifier)
                                .loadDashboardData(estId);
                          }

                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ───────────────────────────────────────────────
// DATA SOURCE 
// ───────────────────────────────────────────────
class _UsersDataSource extends DataTableSource {
  final List<AppUser> users;
  final List<Department> departments;
  final List<dynamic> parkingSpots;
  final Function(AppUser) onEdit;
  final Function(String) onDelete;

  _UsersDataSource({
    required this.users,
    required this.departments,
    required this.parkingSpots,
    required this.onEdit,
    required this.onDelete,
  });

  String _getDepartmentName(String? deptId) {
    if (deptId == null || deptId.isEmpty) return '-';
    try {
      return departments.firstWhere((d) => d.id == deptId).name;
    } catch (_) {
      return '-';
    }
  }

  String _getSpotNumber(String userId) {
    try {
      return parkingSpots.firstWhere((s) => s.assignedUserId == userId).spotNumber;
    } catch (_) {
      return '-';
    }
  }

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final user = users[index];
    return DataRow(
      cells: [
        DataCell(Text(user.displayName)),
        DataCell(Text(user.email)),
        DataCell(Text(user.role)),
        DataCell(Text(_getDepartmentName(user.departmentId))),
        DataCell(Text(_getSpotNumber(user.id))),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => onEdit(user),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => onDelete(user.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => users.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}
