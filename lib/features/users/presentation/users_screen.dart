import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:data_table_2/data_table_2.dart';


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
    // --- 👇 CAMBIO 2: Llamamos al NUEVO controller ---
    Future.microtask(() {
      // Ya no usamos 'adminController.loadUsers'
      ref.read(usersControllerProvider.notifier).loadUsersByDepartment(widget.departmentId);
    });
  }

  @override
  void dispose() {
    _dialogState.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 3: Miramos AMBOS providers ---
    // 1. El NUEVO provider para la lista de usuarios
    final usersState = ref.watch(usersControllerProvider);
    // 2. El VIEJO provider para los métodos CRUD (createUser, etc.)
    final adminController = ref.read(adminControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Departamento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // --- 👇 CAMBIO 4: Refrescamos el NUEVO provider ---
            onPressed: () => ref.read(usersControllerProvider.notifier).loadUsersByDepartment(widget.departmentId),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(
              context,
              adminController, // Sigue usando adminController (está bien)
              widget.departmentId,
              widget.establishmentId,
            ),
          ),
        ],
      ),
      body: usersState.isLoading // <-- Usamos el estado del nuevo provider
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
                empty: Center(child: Text(usersState.error ?? 'No hay usuarios registrados.')), // <-- Usamos el estado del nuevo provider
                rowsPerPage: 20,
                availableRowsPerPage: const [10, 20, 50],
                minWidth: 600,
                showFirstLastButtons: true,
                wrapInCard: false,
                
                source: _UsersDataSource(
                  users: usersState.users, // <-- Usamos la lista del nuevo provider
                  controller: adminController,
                  context: context,
                  dialogState: _dialogState,
                  onEdit: (user) => _showEditDialog(context, adminController, user),
                  onDelete: (userId) => _confirmDelete(context, adminController, userId),
                ),
              ),
            ),
    );
  }

  // --- 👇 CAMBIO 5: Actualizamos los diálogos para que refresquen el NUEVO provider ---

  Future<void> _showAddDialog(
    BuildContext context,
    AdminController controller, // Sigue usando AdminController (OK)
    String departmentId,
    String establishmentId,
  ) async {
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
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                    DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                    
                  ],
                  onChanged: isSaving ? null : (val) => role = val ?? 'TITULAR',
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
                onPressed: isSaving ? null : () async {
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
                    await controller.createUser(user); // Llama al AdminController
                    // --- 👇 Refresca el NUEVO provider ---
                    await ref.read(usersControllerProvider.notifier).loadUsersByDepartment(widget.departmentId);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'))
                      );
                      _dialogState.value = false;
                    }
                  }
                },
                child: Text(isSaving ? 'Guardando...' : 'Guardar'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller, // Sigue usando AdminController (OK)
    AppUser user,
  ) async {
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
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                    DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                    DropdownMenuItem(value: 'SEGURIDAD', child: Text('Seguridad')),
                  ],
                  onChanged: isSaving ? null : (val) => role = val ?? user.role,
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
                onPressed: isSaving ? null : () async {
                  _dialogState.value = true;
                  final updated = user.copyWith(
                    displayName: nameController.text.trim(),
                    email: emailController.text.trim(),
                    role: role,
                  );
                  
                  try {
                    await controller.updateUser(updated); // Llama al AdminController
                    // --- 👇 Refresca el NUEVO provider ---
                    await ref.read(usersControllerProvider.notifier).loadUsersByDepartment(widget.departmentId);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                     if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'))
                      );
                      _dialogState.value = false;
                    }
                  }
                },
                child: Text(isSaving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller, // Sigue usando AdminController (OK)
    String userId,
  ) async {
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
         await controller.deleteUser(userId); // Llama al AdminController
         // --- 👇 Refresca el NUEVO provider ---
         await ref.read(usersControllerProvider.notifier).loadUsersByDepartment(widget.departmentId);
      } catch (e) {
         if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al borrar: ${e.toString()}'))
            );
          }
      }
    }
  }
}

// =================================================================
// ## CLASE AUXILIAR REQUERIDA: DataTableSource
// =================================================================
// (Sin cambios, ya está correcta)

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