import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';

class UsersScreen extends ConsumerStatefulWidget {
  final String departmentId;
  final String establishmentId;

  const UsersScreen({
    super.key,
    required this.departmentId,
    required this.establishmentId,
  });

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _dialogState = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(usersControllerProvider.notifier)
          .loadUsersByDepartment(widget.departmentId);
    });
  }

  @override
  void dispose() {
    _dialogState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersControllerProvider);
    final adminController = ref.read(adminControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Departamento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(usersControllerProvider.notifier)
                .loadUsersByDepartment(widget.departmentId),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(
              context,
              adminController,
              widget.departmentId,
              widget.establishmentId,
            ),
          ),
        ],
      ),
      body: usersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: PaginatedDataTable2(
                columns: const [
                  DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                  DataColumn2(label: Text('Email'), size: ColumnSize.L),
                  DataColumn2(label: Text('Rol'), size: ColumnSize.M),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
                ],
                empty: Center(
                  child: Text(
                    usersState.error ?? 'No hay usuarios registrados.',
                  ),
                ),
                rowsPerPage: 20,
                availableRowsPerPage: const [10, 20, 50],
                minWidth: 600,
                showFirstLastButtons: true,
                wrapInCard: false,

                source: _UsersDataSource(
                  users: usersState.users,
                  controller: adminController,
                  context: context,
                  dialogState: _dialogState,
                  onEdit: (user) =>
                      _showEditDialog(context, adminController, user),
                  onDelete: (userId) =>
                      _confirmDelete(context, adminController, userId),
                ),
              ),
            ),
    );
  }

  // --- 👇 DIÁLOGOS ACTUALIZADOS CON VALIDACIÓN 👇 ---

  Future<void> _showAddDialog(
    BuildContext context,
    AdminController controller,
    String departmentId,
    String establishmentId,
  ) async {
    // --- CAMBIO 1: Añadir FormKey ---
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = 'TITULAR';
    _dialogState.value = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _dialogState,
        builder: (context, isSaving, child) {
          return AlertDialog(
            title: const Text('Nuevo Usuario'),
            // --- CAMBIO 2: Envolver en Form ---
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- CAMBIO 3: Usar TextFormField ---
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !isSaving,
                    // --- CAMBIO 4: Añadir Validadores ---
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    enabled: !isSaving,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El email es obligatorio';
                      }
                      final emailRegex = RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                      );
                      if (!emailRegex.hasMatch(val)) {
                        return 'Formato de email inválido';
                      }
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: const [
                      DropdownMenuItem(
                        value: 'TITULAR',
                        child: Text('Titular'),
                      ),
                      DropdownMenuItem(
                        value: 'SUPLENTE',
                        child: Text('Suplente'),
                      ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (val) => role = val ?? 'TITULAR',
                    decoration: const InputDecoration(labelText: 'Rol'),
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
                        // --- CAMBIO 5: Validar el Formulario ---
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return; // No es válido
                        }
                        // ------------------------------------

                        _dialogState.value = true;
                        final user = AppUser(
                          id: '',
                          displayName: nameController.text.trim(),
                          email: emailController.text.trim(),
                          role: role,
                          departmentId: widget.departmentId,
                          establishmentId: widget.establishmentId,
                          establishmentName: '',
                          vehiclePlates: [],
                        );

                        try {
                          await controller.createUser(user);
                          await ref
                              .read(usersControllerProvider.notifier)
                              .loadUsersByDepartment(widget.departmentId);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                            _dialogState.value = false;
                          }
                        }
                      },
                child: Text(isSaving ? 'Guardando...' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
    // --- CAMBIO 1: Añadir FormKey ---
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    String role = user.role;
    _dialogState.value = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _dialogState,
        builder: (context, isSaving, child) {
          return AlertDialog(
            title: const Text('Editar Usuario'),
            // --- CAMBIO 2: Envolver en Form ---
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- CAMBIO 3: Usar TextFormField ---
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !isSaving,
                    // --- CAMBIO 4: Añadir Validadores ---
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    enabled: !isSaving,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El email es obligatorio';
                      }
                      final emailRegex = RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                      );
                      if (!emailRegex.hasMatch(val)) {
                        return 'Formato de email inválido';
                      }
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: const [
                      DropdownMenuItem(
                        value: 'TITULAR',
                        child: Text('Titular'),
                      ),
                      DropdownMenuItem(
                        value: 'SUPLENTE',
                        child: Text('Suplente'),
                      ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (val) => role = val ?? user.role,
                    decoration: const InputDecoration(labelText: 'Rol'),
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
                        // --- CAMBIO 5: Validar el Formulario ---
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return; // No es válido
                        }
                        // ------------------------------------

                        _dialogState.value = true;
                        final updated = user.copyWith(
                          displayName: nameController.text.trim(),
                          email: emailController.text.trim(),
                          role: role,
                        );

                        try {
                          await controller.updateUser(updated);
                          await ref
                              .read(usersControllerProvider.notifier)
                              .loadUsersByDepartment(widget.departmentId);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                            _dialogState.value = false;
                          }
                        }
                      },
                child: Text(isSaving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller,
    String userId,
  ) async {
    // (Este diálogo no tiene campos de texto, no necesita validación)
    _dialogState.value = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este usuario? ...',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await controller.deleteUser(userId);
        await ref
            .read(usersControllerProvider.notifier)
            .loadUsersByDepartment(widget.departmentId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al borrar: ${e.toString()}')),
          );
        }
      }
    }
  }
}

// ... (Clase _UsersDataSource sin cambios) ...
class _UsersDataSource extends DataTableSource {
  final List<AppUser> users;
  final AdminController controller;
  final BuildContext context;
  final ValueNotifier<bool> dialogState;
  final Function(AppUser) onEdit;
  final Function(String) onDelete;

  _UsersDataSource({
    required this.users,
    required this.controller,
    required this.context,
    required this.dialogState,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) {
      return null;
    }
    final user = users[index];

    return DataRow(
      cells: [
        DataCell(Text(user.displayName)),
        DataCell(Text(user.email)),
        DataCell(Text(user.role)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => onEdit(user),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: Colors.red,
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
