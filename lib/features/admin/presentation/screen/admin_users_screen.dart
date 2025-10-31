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
    // Cargamos los datos iniciales que incluyen la lista de admins y establecimientos
    Future.microtask(() {
      ref.read(adminControllerProvider.notifier).loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);

    // Filtramos para mostrar solo los usuarios con rol 'admin'
    // Y aplicamos el filtro de búsqueda
    final adminUsers = state.users.where((user) {
      final roleMatch = user.role.toLowerCase() == 'admin';
      final q = searchQuery.toLowerCase();
      final queryMatch =
          user.displayName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q);
      return roleMatch && queryMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Administradores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => controller.loadInitialData(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            tooltip: 'Crear Nuevo Admin',
            onPressed: () => _showCreateAdminDialog(context, controller),
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
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                // 1. Usamos el widget PaginatedDataTable2
                : PaginatedDataTable2(
                    // 2. Le pasamos las columnas (igual que antes)
                    columns: const [
                      DataColumn2(label: Text('Nombre'), size: ColumnSize.M),
                      DataColumn2(label: Text('Email'), size: ColumnSize.L),
                      DataColumn2(
                        label: Text('Establecimiento'),
                        size: ColumnSize.L,
                      ),
                      DataColumn2(label: Text('Acciones'), size: ColumnSize.S),
                    ],

                    // 3. Texto si la lista está vacía
                    empty: const Center(
                      child: Text('No se encontraron administradores.'),
                    ),

                    // 4. Esta es la propiedad clave.
                    //    Por defecto es 10. Puedes cambiarla.
                    rowsPerPage: 5,

                    // 5. Opciones para el usuario (opcional pero recomendado)
                    //    Permite al usuario elegir cuántos ver.
                    availableRowsPerPage: const [10, 25, 50],

                    // 6. El "corazón" de la paginación.
                    //    Debes pasarle un objeto que sepa cómo
                    //    construir las filas (DataRow).
                    //    Usaremos una clase auxiliar para esto.
                    source: _AdminDataSource(
                      adminUsers: adminUsers,
                      establishments: state.establishments,
                      controller: controller,
                      context: context,
                      // Le pasamos los métodos de los diálogos
                      showReassignDialog: (user, establishments) =>
                          _showReassignDialog(
                            context,
                            controller,
                            user,
                            establishments,
                          ),
                      showDeleteDialog: (user) =>
                          _showConfirmDeleteDialog(context, controller, user),
                    ),

                    // 7. Ajustes visuales (opcional)
                    minWidth: 800,
                    showFirstLastButtons: true, // Muestra botones "<<" y ">>"
                    wrapInCard: false, // Quita el Card de Material
                  ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGO PARA CREAR UN NUEVO ADMIN ---
  Future<void> _showCreateAdminDialog(
    BuildContext context,
    AdminController controller,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedEstablishmentId; // El admin puede crearse sin asignación
    bool isSaving = false;

    // Obtenemos los establecimientos del estado actual
    final establishments = ref.read(adminControllerProvider).establishments;

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
                    value: selectedEstablishmentId,
                    decoration: const InputDecoration(
                      labelText: 'Asignar a Establecimiento (Opcional)',
                    ),
                    // Añadimos un item para 'No asignar'
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
                          id: '', // Firestore la generará
                          email: emailController.text.trim(),
                          displayName: nameController.text.trim(),
                          role: 'admin', // <-- Rol hardcodeado
                          establishmentId: selectedEstablishmentId ?? '',
                          establishmentName: '', // El repo lo buscará
                          vehiclePlates: const [],
                          departmentId: '', // Los Admins no tienen depto.
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

  Future<void> _showReassignDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
    List<Establishment> allEstablishments,
  ) async {
    // El ID del establecimiento actual del admin.
    // Si no tiene uno (es ''), lo ponemos en null para el Dropdown.
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
                  value: selectedEstablishmentId,
                  decoration: const InputDecoration(
                    labelText: 'Asignar a Establecimiento',
                    border: OutlineInputBorder(),
                  ),
                  // Creamos la lista de opciones
                  items: [
                    // Opción para "quitar" asignación
                    const DropdownMenuItem<String>(
                      value: null, // Representará el 'id' vacío
                      child: Text('No asignar / Quitar asignación'),
                    ),
                    // Lista del resto de establecimientos
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
                          // Obtenemos el nombre del establecimiento (o 'No asignado')
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

                          // Actualizamos el usuario con el nuevo ID y Nombre
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

  // --- MÉTODO PARA CONFIRMAR ELIMINACIÓN DE ADMIN ---
  Future<void> _showConfirmDeleteDialog(
    BuildContext context,
    AdminController controller,
    AppUser user,
  ) async {
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
                    'Esta acción no se puede deshacer. El usuario se eliminará permanentemente de la base de datos.',
                  ),
            actions: isDeleting
                ? [] // Oculta botones mientras elimina
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
                          // 1. Llama al controller para eliminar
                          await controller.deleteUser(user.id);

                          // 2. Cierra el diálogo
                          if (context.mounted) Navigator.pop(context);

                          // 3. Muestra confirmación (opcional)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin eliminado correctamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          // Si hay error, cierra y muéstralo
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

// -----------------------------------------------------------------
// ## CLASE AUXILIAR REQUERIDA: DataTableSource
// -----------------------------------------------------------------
//
// Esta clase es la que `PaginatedDataTable2` usa para saber
// qué datos mostrar en cada página.
//
// -----------------------------------------------------------------

class _AdminDataSource extends DataTableSource {
  final List<AppUser> adminUsers;
  final List<Establishment> establishments;
  final AdminController controller;
  final BuildContext context;
  // Funciones callback para los diálogos
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

  // 1. Construye UNA fila
  @override
  DataRow? getRow(int index) {
    if (index >= adminUsers.length) {
      return null;
    }
    final user = adminUsers[index];

    // Lógica para buscar el nombre (la misma que tenías)
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

    // Devuelve la misma DataRow que ya tenías
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

  // 2. Le dice a la tabla cuántas filas hay en total (después de filtrar)
  @override
  int get rowCount => adminUsers.length;

  // 3. Le dice si la data cambió (siempre true para simplificar)
  @override
  bool get isRowCountApproximate => false;

  // 4. Le dice cuál es la fila seleccionada (ninguna)
  @override
  int get selectedRowCount => 0;
}
