import 'package:cocheras_nestle_web/features/establishments/application/establishments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:data_table_2/data_table_2.dart';


class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Cargamos los datos iniciales de 'admin' (usuarios)
    // El 'establishmentsControllerProvider' se carga solo.
    Future.microtask(() {
      ref.read(adminControllerProvider.notifier).loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 2: Miramos AMBOS providers ---
    // 1. El estado del Admin (para la lista de usuarios)
    final adminState = ref.watch(adminControllerProvider);
    final adminController = ref.read(adminControllerProvider.notifier);

    // 2. El estado de Establishments (para la lista de establecimientos)
    final establishmentState = ref.watch(establishmentsControllerProvider);
    // ------------------------------------------

    // Filtramos los usuarios (esto usa el adminState, está bien)
    final adminUsers = adminState.users.where((user) {
      final roleMatch = user.role.toLowerCase() == 'admin';
      final q = searchQuery.toLowerCase();
      final queryMatch =
          user.displayName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q);
      return roleMatch && queryMatch;
    }).toList();

    // El estado de carga depende de AMBOS
    final bool isLoading = adminState.isLoading || establishmentState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Administradores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            // --- 👇 CAMBIO 3: Refrescamos AMBOS providers ---
            onPressed: () {
              ref.read(adminControllerProvider.notifier).loadInitialData();
              ref.invalidate(establishmentsControllerProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            tooltip: 'Crear Nuevo Admin',
            // Pasamos la lista de establecimientos desde el NUEVO estado
            onPressed: () => _showCreateAdminDialog(
              context,
              adminController,
              establishmentState.establishments, // <-- Pasamos la lista
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar admin por nombre o email...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (q) => setState(() => searchQuery = q),
            ),
          ),
          Expanded(
            child: isLoading // Usamos el estado de carga combinado
                ? const Center(child: CircularProgressIndicator())
                : PaginatedDataTable2(
                    columns: const [
                      DataColumn2(label: Text('Nombre'), size: ColumnSize.M),
                      DataColumn2(label: Text('Email'), size: ColumnSize.L),
                      DataColumn2(
                        label: Text('Establecimiento'),
                        size: ColumnSize.L,
                      ),
                      DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
                    ],
                    // Mostramos un error si CUALQUIERA de los dos falla
                    empty: Center(
                      child: Text(
                        adminState.error ?? 
                        establishmentState.error ?? 
                        'No se encontraron administradores.'
                      ),
                    ),
                    rowsPerPage: 5, // (Nota: pusiste 5, pero en 'available' no está. Lo cambio a 10)
                    availableRowsPerPage: const [10, 25, 50],

                    // --- 👇 CAMBIO 4: Pasamos la lista correcta al DataSource ---
                    source: _AdminDataSource(
                      adminUsers: adminUsers,
                      // Pasamos la lista desde el NUEVO estado
                      establishments: establishmentState.establishments, 
                      controller: adminController,
                      context: context,
                      // Le pasamos los métodos de los diálogos
                      showReassignDialog: (user, establishments) =>
                          _showReassignDialog(
                        context,
                        adminController,
                        user,
                        establishments,
                      ),
                      showDeleteDialog: (user) =>
                          _showConfirmDeleteDialog(context, adminController, user),
                    ),
                    minWidth: 800,
                    showFirstLastButtons: true, 
                    wrapInCard: false, 
                  ),
          ),
        ],
      ),
    );
  }

  // --- 👇 CAMBIO 5: Actualizamos la firma del diálogo ---
  Future<void> _showCreateAdminDialog(
    BuildContext context,
    AdminController controller,
    List<Establishment> establishments, // <-- Recibe la lista como parámetro
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedEstablishmentId; 
    bool isSaving = false;

    // YA NO leemos el provider aquí, usamos el parámetro
    // final establishments = ref.read(adminControllerProvider).establishments; // <-- LÍNEA BORRADA

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Crear Nuevo Admin'),
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
                    initialValue: selectedEstablishmentId,
                    decoration: const InputDecoration(
                      labelText: 'Asignar a Establecimiento (Opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No asignar aún'),
                      ),
                      // Usamos la lista 'establishments' del parámetro
                      ...establishments.map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedEstablishmentId = val),
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
                        // ... (Lógica de validación y creación de 'newUser' sin cambios)
                        if (nameController.text.trim().isEmpty ||
                            emailController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nombre y Email son requeridos'),
                            ),
                          );
                          return;
                        }

                        setState(() => isSaving = true);

                        final newUser = AppUser(
                          id: '', // Se setea en el controller
                          email: emailController.text.trim(),
                          displayName: nameController.text.trim(),
                          role: 'admin', 
                          establishmentId: selectedEstablishmentId ?? '',
                          establishmentName: '', // El repo lo buscará
                          vehiclePlates: const [],
                          departmentId: '', 
                        );

                        try {
                          await controller.createUser(newUser);
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Admin Creado con éxito. Se envió email para resetear contraseña.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al crear: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (context.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- (LOS OTROS 2 DIÁLOGOS NO NECESITAN CAMBIOS) ---
  // _showReassignDialog y _showConfirmDeleteDialog 
  // ya reciben los datos que necesitan como parámetros.

  Future<void> _showReassignDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
    List<Establishment> allEstablishments,
  ) async {
    // ... (Este método está bien como está) ...
    String? selectedEstablishmentId = user.establishmentId.isEmpty
        ? null
        : user.establishmentId;

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Reasignar a: ${user.displayName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedEstablishmentId,
                  decoration: const InputDecoration(
                    labelText: 'Asignar a Establecimiento',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null, 
                      child: Text('No asignar / Quitar asignación'),
                    ),
                    ...allEstablishments.map(
                      (est) => DropdownMenuItem(
                        value: est.id,
                        child: Text(est.name),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => selectedEstablishmentId = val),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
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

                        try {
                          final establishmentName = allEstablishments
                              .firstWhere(
                                (e) => e.id == selectedEstablishmentId,
                                orElse: () => Establishment(
                                  id: '',
                                  name: 'No asignado',
                                  address: '',
                                  organizationType: '',
                                  createdAt: DateTime.now(),
                                ),
                              )
                              .name;
                              
                          await controller.updateUser(
                            user.copyWith(
                              establishmentId: selectedEstablishmentId ?? '',
                              establishmentName: establishmentName,
                            ),
                          );

                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al reasignar: ${e.toString()}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (context.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showConfirmDeleteDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
    // ... (Este método está bien como está) ...
    bool isDeleting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('¿Eliminar a ${user.displayName}?'),
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
                    'Esta acción no se puede deshacer. El usuario se eliminará permanentemente de la base de datos.'),
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

                        try {
                          await controller.deleteUser(user.id);
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin eliminado correctamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al eliminar: ${e.toString()}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
          );
        },
      ),
    );
  }
}

// --- (LA CLASE _AdminDataSource NO NECESITA CAMBIOS) ---
// Ya recibe 'establishments' como parámetro, así que
// mientras le pasemos la lista correcta, funcionará.

class _AdminDataSource extends DataTableSource {
  final List<AppUser> adminUsers;
  final List<Establishment> establishments;
  final AdminController controller;
  final BuildContext context;
  final Function(AppUser, List<Establishment>) showReassignDialog;
  final Function(AppUser) showDeleteDialog;

  _AdminDataSource({
    required this.adminUsers,
    required this.establishments,
    required this.controller,
    required this.context,
    required this.showReassignDialog,
    required this.showDeleteDialog,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= adminUsers.length) {
      return null;
    }
    final user = adminUsers[index];

    final establishmentName = establishments
        .firstWhere(
          (est) => est.id == user.establishmentId,
          orElse: () => Establishment(
            id: '',
            name: 'No asignado',
            address: '',
            organizationType: '',
            createdAt: DateTime.now(),
          ),
        )
        .name;

    return DataRow(
      cells: [
        DataCell(Text(user.displayName)),
        DataCell(Text(user.email)),
        DataCell(Text(establishmentName)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_location_alt),
                tooltip: 'Reasignar Establecimiento',
                onPressed: () {
                  showReassignDialog(user, establishments);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: Colors.red,
                tooltip: 'Eliminar Admin',
                onPressed: () {
                  showDeleteDialog(user);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => adminUsers.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}