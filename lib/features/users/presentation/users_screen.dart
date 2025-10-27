import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminControllerProvider.notifier).loadUsers(widget.departmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Departamento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.loadUsers(widget.departmentId),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(
              context,
              controller,
              widget.departmentId,
              widget.establishmentId,
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.users.isEmpty
          ? const Center(child: Text('No hay usuarios registrados.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Rol')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: state.users.map((user) {
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
                              onPressed: () =>
                                  _showEditDialog(context, controller, user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colors.red,
                              onPressed: () =>
                                  _confirmDelete(context, controller, user.id),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    AdminController controller,
    String departmentId,
    String establishmentId,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = 'TITULAR';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                DropdownMenuItem(
                  value: 'SUPERADMIN',
                  child: Text('Superadmin'),
                ),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                DropdownMenuItem(value: 'SEGURIDAD', child: Text('Seguridad')),
              ],
              onChanged: (val) => role = val ?? 'TITULAR',
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = AppUser(
                id: '',
                displayName: nameController.text.trim(),
                email: emailController.text.trim(),
                role: role,
                departmentId: widget.departmentId,
                establishmentId: widget.establishmentId,
                establishmentName: widget.establishmentId,
                vehiclePlates: [],
              );
              await controller.createUser(
                user,
              ); // Método que habrá que agregar en AdminController
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    String role = user.role;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                DropdownMenuItem(
                  value: 'SUPERADMIN',
                  child: Text('Superadmin'),
                ),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                DropdownMenuItem(value: 'SEGURIDAD', child: Text('Seguridad')),
              ],
              onChanged: (val) => role = val ?? user.role,
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = user.copyWith(
                displayName: nameController.text.trim(),
                email: emailController.text.trim(),
                role: role,
              );
              await controller.updateUser(
                updated,
              ); // Método que también hay que tener
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller,
    String userId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este usuario? Esta acción no se puede deshacer.',
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
      await controller.deleteUser(userId);
    }
  }
}
