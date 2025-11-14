import 'package:cocheras_nestle_web/features/establishments/application/establishments_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:data_table_2/data_table_2.dart';

// --- 👇 CAMBIO 1: Importar el UsersController ---
import 'package:cocheras_nestle_web/features/users/application/users_controller.dart'; 


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
    // --- 👇 CAMBIO 2: Llamamos al NUEVO controller ---
    Future.microtask(() {
      // Ya no llamamos a adminController.loadInitialData()
      ref.read(usersControllerProvider.notifier).loadAdmins();
      // El 'establishmentsControllerProvider' se carga solo (o desde su propio initState).
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 CAMBIO 3: Miramos los providers correctos ---
    // 1. El AdminController (solo para 'createUser', 'deleteUser', 'updateUser')
    final adminController = ref.read(adminControllerProvider.notifier);

    // 2. El EstablishmentsState (para la lista de establecimientos)
    final establishmentState = ref.watch(establishmentsControllerProvider);
    
    // 3. El NUEVO UsersState (para la lista de admins)
    final usersState = ref.watch(usersControllerProvider);
    // ------------------------------------------

    // Filtramos la lista de admins (ahora usa 'usersState')
    final adminUsers = usersState.users.where((user) {
      // (El filtro de 'roleMatch' ya no es necesario,
      //  porque la lista ya viene filtrada desde el controller)
      final q = searchQuery.toLowerCase();
      final queryMatch =
          user.displayName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q);
      return queryMatch;
    }).toList();

    // El estado de carga depende de los providers que leemos
    final bool isLoading = usersState.isLoading || establishmentState.isLoading;
    final String? error = usersState.error ?? establishmentState.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Administradores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            // --- 👇 CAMBIO 4: Refrescamos los providers correctos ---
            onPressed: () {
              ref.read(usersControllerProvider.notifier).loadAdmins();
              ref.invalidate(establishmentsControllerProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            tooltip: 'Crear Nuevo Admin',
            onPressed: () => _showCreateAdminDialog(
              context,
              adminController,
              establishmentState.establishments, 
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
            child: isLoading
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
                    empty: Center(
                      child: Text(
                        error ?? 
                        'No se encontraron administradores.'
                      ),
                    ),
                    rowsPerPage: 10, // Ajustado para que coincida
                    availableRowsPerPage: const [10, 25, 50],

                    // --- 👇 CAMBIO 5: Pasamos el UsersController a los diálogos ---
                    source: _AdminDataSource(
                      adminUsers: adminUsers,
                      establishments: establishmentState.establishments, 
                      controller: adminController,
                      context: context,
                      // Pasamos el notifier para que los diálogos puedan refrescar
                      usersNotifier: ref.read(usersControllerProvider.notifier), 
                      showReassignDialog: (user, establishments) =>
                          _showReassignDialog(
                        context,
                        adminController,
                        ref.read(usersControllerProvider.notifier), // Pasa el notifier
                        user,
                        establishments,
                      ),
                      showDeleteDialog: (user) =>
                          _showConfirmDeleteDialog(
                            context, 
                            adminController, 
                            ref.read(usersControllerProvider.notifier), // Pasa el notifier
                            user
                          ),
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

  // --- 👇 CAMBIO 6: Diálogos actualizados para refrescar el provider correcto ---
  // (Y con la validación que hicimos en el mensaje 221)

  Future<void> _showCreateAdminDialog(
    BuildContext context,
    AdminController controller,
    List<Establishment> establishments,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedEstablishmentId; 
    bool isSaving = false;
    late BuildContext dialogContext; 

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Crear Nuevo Admin'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El email es obligatorio';
                          }
                          final emailRegex = RegExp(
                              r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                          if (!emailRegex.hasMatch(value)) {
                            return 'Formato de email inválido';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          ...establishments.map(
                            (d) =>
                                DropdownMenuItem(value: d.id, child: Text(d.name)),
                          ),
                        ],
                        onChanged: isSaving ? null : (val) =>
                            setState(() => selectedEstablishmentId = val),
                      ),
                      if (isSaving) ...[
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text("Creando..."),
                      ],
                    ],
                  ),
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
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          
                          setState(() => isSaving = true);

                          final newUser = AppUser.empty().copyWith(
                            email: emailController.text.trim(),
                            displayName: nameController.text.trim(),
                            role: 'admin', 
                            establishmentId: selectedEstablishmentId ?? '',
                          );

                          try {
                            await controller.createUser(newUser);
                            
                            // --- 👇 Refrescamos el provider de admins ---
                            ref.read(usersControllerProvider.notifier).loadAdmins();
                            
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Admin Creado con éxito. Se envió email para resetear contraseña.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(isSaving ? "Creando..." : "Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showReassignDialog(
    BuildContext context,
    AdminController controller,
    UsersController usersNotifier, // <-- Recibe el notifier
    AppUser user,
    List<Establishment> allEstablishments,
  ) async {
    String? selectedEstablishmentId = user.establishmentId.isEmpty
        ? null
        : user.establishmentId;
    bool isSaving = false;
    late BuildContext dialogContext;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
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
                    onPressed: () => Navigator.pop(dialogContext),
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
                                  orElse: () => Establishment.empty(),
                                )
                                .name;
                                
                            await controller.updateUser(
                              user.copyWith(
                                establishmentId: selectedEstablishmentId ?? '',
                                establishmentName: establishmentName == 'No asignado' ? '' : establishmentName,
                              ),
                            );

                            // --- 👇 Refresca el provider de admins ---
                            usersNotifier.loadAdmins();

                            if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                            if (dialogContext.mounted) {
                              setState(() => isSaving = false);
                            }
                          }
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

  Future<void> _showConfirmDeleteDialog(
    BuildContext context,
    AdminController controller,
    UsersController usersNotifier, // <-- Recibe el notifier
    AppUser user,
  ) async {
    bool isDeleting = false;
    late BuildContext dialogContext;

    await showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
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
                        onPressed: () => Navigator.pop(dialogContext),
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
                            
                            // --- 👇 Refresca el provider de admins ---
                            usersNotifier.loadAdmins();
                            
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Admin eliminado correctamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
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
        );
      },
    );
  }
}


// --- 👇 CAMBIO 7: Actualizar el DataSource ---
class _AdminDataSource extends DataTableSource {
  final List<AppUser> adminUsers;
  final List<Establishment> establishments;
  final AdminController controller;
  final UsersController usersNotifier; // <-- Recibe el notifier
  final BuildContext context;
  final Function(AppUser, List<Establishment>) showReassignDialog;
  final Function(AppUser) showDeleteDialog;

  _AdminDataSource({
    required this.adminUsers,
    required this.establishments,
    required this.controller,
    required this.usersNotifier, // <-- Recibe el notifier
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
          orElse: () => Establishment.empty(),
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