// global_users_screen.dart
import 'package:cocheras_nestle_web/features/departments/application/departments_controller.dart';
import 'package:cocheras_nestle_web/features/departments/domain/models/department_model.dart';
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart';
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
    // --- 👇 VOLVEMOS AL initState ESTABLE ---
    Future.microtask(() async {
      final establishmentId = ref.read(authControllerProvider).value?.establishmentId;
      if (establishmentId == null) return;
      
      // 1. Carga los datos del Admin (users, spots, etc.)
      ref.read(adminControllerProvider.notifier).loadDashboardData(establishmentId);
      
      // 2. Carga los departamentos (para el dropdown)
      ref.read(departmentsControllerProvider.notifier).load(establishmentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 VOLVEMOS A LEER LOS PROVIDERS ESTABLES ---
    final adminState = ref.watch(adminControllerProvider);
    final adminController = ref.read(adminControllerProvider.notifier);
    final departmentState = ref.watch(departmentsControllerProvider);
    // (Borramos usersState)
    // ------------------------------------------

    final bool isLoading = adminState.isLoading || departmentState.isLoading;
    final String? error = adminState.error ?? departmentState.error;

    // --- 👇 Leemos 'users' del adminState (COMO ANTES) ---
    final users = adminState.users.where((u) { // Filtro local
      final q = searchQuery.toLowerCase();
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
    
    final departments = departmentState.departments;
    final parkingSpots = adminState.parkingSpots; 
    // -------------------------------------------------------------------

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Establecimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // Refrescamos los providers estables
            onPressed: () {
              final establishmentId = ref.read(authControllerProvider).value?.establishmentId;
              if (establishmentId == null) return;
              
              ref.read(adminControllerProvider.notifier).loadDashboardData(establishmentId); 
              ref.read(departmentsControllerProvider.notifier).load(establishmentId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Usuario',
            onPressed: () => _showCreateUserDialog(context, adminController, departments),
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
                    ? Center(child: Text(error ?? 'No hay usuarios registrados.'))
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
                              departmentName = departments
                                  .firstWhere((d) => d.id == user.departmentId)
                                  .name;
                            } catch (_) { /* no-op */ }

                            String spotNumber = '-';
                            try {
                              spotNumber = parkingSpots
                                  .firstWhere((s) => s.assignedUserId == user.id)
                                  .spotNumber;
                            } catch (_) { /* no-op */ }

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
                                          adminController,
                                          user,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        onPressed: () => _confirmDelete(
                                          context,
                                          adminController,
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

  // --- 👇 Diálogos VUELTOS A LA NORMALIDAD (llaman a loadDashboardData) ---
  
  // En global_users_screen.dart

  Future<void> _confirmDelete(
    BuildContext context,
    AdminController controller,
    String userId,
  ) async {
    bool isDeleting = false;
    // Usamos 'dialogContext' para poder cerrarlo
    // sin depender del 'context' del StatefulBuilder
    late BuildContext dialogContext; 

    await showDialog(
      context: context,
      // Hacemos que la barrera no se pueda cerrar NUNCA mientras está en 'isDeleting'
      // Para eso, necesitamos que el StatefulBuilder maneje su *propio* barrierDismissible
      // Pero eso es complejo. Lo más simple es hacerlo no-descartable.
      barrierDismissible: false, // <-- CAMBIO SIMPLE
      builder: (context) {
        dialogContext = context; // Guardamos el context del diálogo
        return StatefulBuilder(
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
                  : const Text(
                      '¿Estás seguro de que querés eliminar este usuario? ...'),
              actions: isDeleting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext), // Cierra con el context bueno
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          setState(() => isDeleting = true);
                          
                          try {
                            await controller.deleteUser(userId);
                            
                            final establishmentId = ref.read(authControllerProvider).value?.establishmentId;
                            if (establishmentId != null) {
                              // ¡AWAITEAMOS la recarga!
                              await ref.read(usersControllerProvider.notifier).loadUsersByEstablishment(establishmentId);
                            }
                            
                            // Comprobamos si el diálogo AÚN existe
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Usuario eliminado correctamente'),
                                duration: Duration(seconds: 2),
                              ),
                            );

                          } catch (e) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al eliminar: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          // No necesitamos 'finally' porque el pop está en el try/catch
                        },
                        child: const Text('Eliminar'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

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
    
    // Contexto del diálogo
    late BuildContext dialogContext; 

    await showDialog(
      context: context,
      barrierDismissible: false, // <-- CAMBIO SIMPLE
      builder: (context) {
        dialogContext = context;
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
                        DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
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
                    onPressed: () => Navigator.pop(dialogContext),
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
                            departmentId: (selectedRole == 'TITULAR' ||
                                    selectedRole == 'SUPLENTE')
                                ? (selectedDepartmentId ?? '')
                                : '',
                          );
                          
                          try {
                            await controller.createUser(newUser);
                            
                            final establishmentId = ref.read(authControllerProvider).value?.establishmentId;
                            if (establishmentId != null) {
                              // ¡AWAITEAMOS la recarga!
                              await ref.read(usersControllerProvider.notifier).loadUsersByEstablishment(establishmentId);
                            }
                            
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                          } catch (e) {
                            // Si falla, mostramos el error pero NO cerramos el diálogo
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              // Dejamos que el usuario corrija
                              setState(() => isSaving = false); 
                            }
                          }
                          // No ponemos 'finally' para que el diálogo
                          // solo se cierre si todo salió bien.
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

  Future<void> _showEditDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = user.role;
    bool isSaving = false; // <-- Añadido
    
    late BuildContext dialogContext;

    await showDialog(
      context: context,
      barrierDismissible: false, // <-- CAMBIO SIMPLE
      builder: (context) {
        dialogContext = context;
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
                    enabled: !isSaving, // <-- Añadido
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    enabled: !isSaving, // <-- Añadido
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'TITULAR', child: Text('Titular')),
                      DropdownMenuItem(value: 'SUPLENTE', child: Text('Suplente')),
                    ],
                    onChanged: isSaving ? null : (val) => selectedRole = val ?? user.role, // <-- Añadido
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
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async { // <-- Añadido
                    setState(() => isSaving = true); // <-- Añadido
                    
                    final updated = user.copyWith(
                      displayName: nameController.text.trim(),
                      email: emailController.text.trim(),
                      role: selectedRole,
                    );
                    
                    try {
                      await controller.updateUser(updated);
                      
                      final establishmentId = ref.read(authControllerProvider).value?.establishmentId;
                      if (establishmentId != null) {
                          // ¡AWAITEAMOS la recarga!
                          await ref.read(usersControllerProvider.notifier).loadUsersByEstablishment(establishmentId);
                      }
                      
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al actualizar: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setState(() => isSaving = false); // <-- Dejamos que corrija
                      }
                    }
                  },
                  child: Text(isSaving ? 'Guardando...' : 'Guardar cambios'), // <-- Añadido
                ),
              ],
            );
          }
        );
      },
    );
  }
}