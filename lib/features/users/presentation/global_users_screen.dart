import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final controller = ref.read(adminControllerProvider.notifier);
      await controller.loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);

    final users = state.users.where((u) {
      final q = searchQuery.toLowerCase();
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Establecimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // --- CAMBIO CLAVE ---
              controller.loadInitialData();
              // --- FIN DEL CAMBIO ---
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Usuario',
            onPressed: () => _showCreateUserDialog(context, controller),
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
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                ? const Center(child: Text('No hay usuarios registrados.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Rol')),
                        DataColumn(label: Text('Departamento')),
                        DataColumn(label: Text('Cochera')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: users.map((user) {
                        String departmentName = '-';
                        try {
                          departmentName = state.departments
                              .firstWhere((d) => d.id == user.departmentId)
                              .name;
                        } catch (_) {
                          departmentName = '-';
                        }

                        String spotNumber = '-';
                        try {
                          spotNumber = state.parkingSpots
                              .firstWhere((s) => s.assignedUserId == user.id)
                              .spotNumber;
                        } catch (_) {
                          spotNumber = '-';
                        }

                        return DataRow(
                          cells: [
                            DataCell(Text(user.displayName)),
                            DataCell(Text(user.email)),
                            DataCell(Text(user.role)),
                            DataCell(Text(departmentName)),
                            DataCell(Text(spotNumber)),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditDialog(
                                      context,
                                      controller,
                                      user,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _confirmDelete(
                                      context,
                                      controller,
                                      user.id,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
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
    bool isDeleting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isDeleting,
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
                      Text(
                        'Eliminando usuario...',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  )
                : const Text(
                    '¿Estás seguro de que querés eliminar este usuario? Esta acción no se puede deshacer.',
                  ),
            actions: isDeleting
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        setState(() => isDeleting = true);
                        await controller.deleteUser(userId);

                        await controller.loadInitialData();

                        setState(() => isDeleting = false);
                        if (context.mounted) Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Usuario eliminado correctamente'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  // --- DIALOGO CREAR USUARIO (SIN CAMBIOS) ---
  Future<void> _showCreateUserDialog(
    BuildContext context,
    AdminController controller,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'TITULAR';
    String? selectedDepartmentId;
    bool isSaving = false;

    final state = ref.read(adminControllerProvider);
    final departments = state.departments;
    final authUser = ref.read(authControllerProvider).value;
    final currentEstablishmentId = authUser?.establishmentId ?? '';

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
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
                      DropdownMenuItem(
                        value: 'TITULAR',
                        child: Text('Titular'),
                      ),
                      DropdownMenuItem(
                        value: 'SUPLENTE',
                        child: Text('Suplente'),
                      ),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                      DropdownMenuItem(
                        value: 'SEGURIDAD',
                        child: Text('Seguridad'),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedRole = val ?? 'TITULAR'),
                  ),
                  const SizedBox(height: 8),
                  if (selectedRole == 'TITULAR' || selectedRole == 'SUPLENTE')
                    DropdownButtonFormField<String>(
                      initialValue: selectedDepartmentId,
                      decoration: const InputDecoration(
                        labelText: 'Departamento',
                      ),
                      items: departments
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedDepartmentId = val),
                    ),
                  if (isSaving) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text(
                      "Creando usuario...",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
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
                              content: Text('Complete todos los campos'),
                            ),
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
                          departmentId:
                              (selectedRole == 'TITULAR' ||
                                  selectedRole == 'SUPLENTE')
                              ? (selectedDepartmentId ?? '')
                              : '',
                        );

                        await controller.createUser(newUser);
                        await controller.loadInitialData();

                        setState(() => isSaving = false);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- EDITAR USUARIO (SIN CAMBIOS) ---
  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = user.role;

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
              initialValue: selectedRole,
              items: const [
                DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'SEGURIDAD', child: Text('Seguridad')),
              ],
              onChanged: (val) => selectedRole = val ?? user.role,
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
                role: selectedRole,
              );
              await controller.updateUser(updated);
              await controller.loadInitialData();

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
