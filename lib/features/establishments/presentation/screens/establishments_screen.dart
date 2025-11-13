import 'dart:convert'; // Necesario para json.decode
import 'package:cocheras_nestle_web/features/establishments/application/establishments_controller.dart';
import 'package:cocheras_nestle_web/features/users/models/app_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cocheras_nestle_web/features/admin/presentation/screen/assign_Admin_screen.dart';
import 'package:cocheras_nestle_web/features/admin/providers/admin_controller_provider.dart';
import 'package:cocheras_nestle_web/features/establishments/domain/models/establishment_model.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http; // Necesario para las llamadas a la API

class EstablishmentsScreen extends ConsumerStatefulWidget {
  const EstablishmentsScreen({super.key});

  @override
  ConsumerState<EstablishmentsScreen> createState() =>
      _EstablishmentsScreenState();
}

class _EstablishmentsScreenState extends ConsumerState<EstablishmentsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminControllerProvider.notifier).loadInitialData();
    });
  }

  String _getAdminName(List<AppUser> allUsers, String establishmentId) {
    try {
      final admin = allUsers.firstWhere(
        (user) =>
            user.role == 'admin' && user.establishmentId == establishmentId,
      );
      return admin.displayName;
    } catch (e) {
      return 'Sin asignar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final establishmentState = ref.watch(establishmentsControllerProvider);
    final establishmentsController = ref.read(
      establishmentsControllerProvider.notifier,
    );

    final adminState = ref.watch(adminControllerProvider);
    final List<AppUser> allUsers = adminState.users;

    final bool isLoading = establishmentState.isLoading || adminState.isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Establecimientos Nestlé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(establishmentsControllerProvider);
              ref.read(adminControllerProvider.notifier).loadInitialData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, establishmentsController),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: DataTable2(
                empty: Center(
                  child: Text(
                    establishmentState.error ??
                        adminState.error ??
                        'No hay establecimientos registrados.',
                  ),
                ),
                minWidth: 700,
                columns: const [
                  DataColumn2(label: Text('Nombre'), size: ColumnSize.M),
                  DataColumn2(label: Text('Dirección'), size: ColumnSize.L),
                  DataColumn2(label: Text('Tipo'), size: ColumnSize.S),
                  DataColumn2(label: Text('Administrador'), size: ColumnSize.M),
                  DataColumn2(label: Text('Acciones'), size: ColumnSize.M),
                ],
                rows: establishmentState.establishments.map((e) {
                  // --- 👇 USAMOS LA NUEVA FUNCIÓN SEGURA 👇 ---
                  final adminName = _getAdminName(allUsers, e.id);

                  return DataRow(
                    cells: [
                      DataCell(Text(e.name)),
                      DataCell(Text(e.address)),
                      DataCell(Text(e.organizationType)),
                      DataCell(Text(adminName)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () => _showEditDialog(
                                context,
                                establishmentsController,
                                e,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar',
                              color: Colors.red,
                              onPressed: () => _confirmDelete(
                                context,
                                establishmentsController,
                                e.id,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_add),
                              tooltip: 'Asignar Administrador',
                              color: Colors.blue,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AssignAdminScreen(establishment: e),
                                  ),
                                );
                              },
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

  final String geoapifyKey = '8e6bd6534958434f8db83ead26538100';

  Future<void> _showAddDialog(
    BuildContext context,
    EstablishmentsController controller,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String orgType = 'DEPARTAMENTAL';
    Map<String, dynamic>? selectedPlace;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Establecimiento'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Campo obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                TypeAheadField<Map<String, dynamic>>(
                  suggestionsCallback: (pattern) async {
                    final uri = Uri.parse(
                      'https://api.geoapify.com/v1/geocode/autocomplete'
                      '?text=${Uri.encodeComponent(pattern)}'
                      '&lang=es&filter=countrycode:ar&apiKey=$geoapifyKey',
                    );

                    try {
                      final response = await http.get(uri);
                      if (response.statusCode == 200) {
                        final data = json.decode(response.body);
                        final features = data['features'] as List?;
                        if (features == null || features.isEmpty) {
                          debugPrint(
                            'Geoapify OK (200), pero no se encontraron features.',
                          );
                          return [];
                        }

                        debugPrint(
                          'Geoapify OK (200): Encontró ${features.length} features.',
                        );
                        return features
                            .map((f) => f['properties'] as Map<String, dynamic>)
                            .toList();
                      } else {
                        debugPrint('Geoapify error: ${response.statusCode}');
                        return [];
                      }
                    } catch (e) {
                      debugPrint('Geoapify exception: $e');
                      return [];
                    }
                  },
                  itemBuilder: (context, suggestion) => ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(suggestion['formatted'] ?? ''),
                  ),
                  onSelected: (suggestion) {
                    addressController.text = suggestion['formatted'] ?? '';
                    selectedPlace = suggestion;
                  },
                  // ⚠️ ESTA PARTE ES CLAVE
                  builder: (context, textController, focusNode) {
                    // Sincronizamos el interno con el externo
                    textController.text = addressController.text;
                    textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: textController.text.length),
                    );

                    textController.addListener(() {
                      addressController.text = textController.text;
                    });

                    return TextFormField(
                      controller:
                          textController, // ✅ usamos el que maneja el paquete
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Seleccione una dirección válida';
                        }
                        if (selectedPlace == null) {
                          return 'Seleccione una dirección de la lista';
                        }
                        return null;
                      },
                    );
                  },
                  emptyBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No se encontraron direcciones.'),
                  ),
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: orgType,
                  items: const [
                    DropdownMenuItem(
                      value: 'DEPARTAMENTAL',
                      child: Text('Departamental'),
                    ),
                    DropdownMenuItem(
                      value: 'UNIFICADO',
                      child: Text('Unificado'),
                    ),
                  ],
                  onChanged: (val) => orgType = val ?? 'DEPARTAMENTAL',
                  decoration: const InputDecoration(
                    labelText: 'Tipo de organización',
                    prefixIcon: Icon(Icons.category),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final est = Establishment(
                id: '',
                name: nameController.text.trim(),
                address: addressController.text.trim(),
                organizationType: orgType,
                createdAt: DateTime.now(),
                latitude: selectedPlace?['lat']?.toDouble(),
                longitude: selectedPlace?['lon']?.toDouble(),
              );
              await controller.create(est);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // --- 👇 CÓDIGO CON MÁS PRINTS DE DEPURACIÓN 👇 ---
  Future<void> _showEditDialog(
    BuildContext context,
    EstablishmentsController controller,
    Establishment establishment,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: establishment.name);
    final addressController = TextEditingController(
      text: establishment.address,
    );
    String orgType = establishment.organizationType;

    Map<String, dynamic>? selectedProperties = {
      'lat': establishment.latitude,
      'lon': establishment.longitude,
      'formatted': establishment.address,
    };

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Establecimiento'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingrese un nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TypeAheadField<Map<String, dynamic>>(
                  suggestionsCallback: (pattern) async {
                    // --- 👇 AÑADIMOS PRINTS AQUÍ 👇 ---
                    debugPrint('--- suggestionsCallback (EDIT) INICIADO ---');
                    debugPrint('Pattern: "$pattern"');

                    if (pattern.length < 3) {
                      debugPrint(
                        'Pattern demasiado corto, devolviendo lista vacía.',
                      );
                      return [];
                    }

                    final geoapifyUrl =
                        'https://api.geoapify.com/v1/geocode/autocomplete'
                        '?text=${Uri.encodeComponent(pattern)}'
                        '&lang=es&filter=countrycode:ar&apiKey=$geoapifyKey';

                    // Pasamos la URL por un proxy que agrega los headers de CORS
                    final uri = Uri.parse(
                      'https://corsproxy.io/?${Uri.encodeComponent(geoapifyUrl)}',
                    );

                    try {
                      final response = await http.get(uri);
                      if (response.statusCode == 200) {
                        final data = json.decode(response.body);
                        final features = data['features'] as List?;
                        if (features == null || features.isEmpty) {
                          debugPrint(
                            'Geoapify OK (200), pero no se encontraron features.',
                          );
                          return [];
                        }

                        debugPrint(
                          'Geoapify OK (200): Encontró ${features.length} features.',
                        );
                        return features
                            .map((f) => f['properties'] as Map<String, dynamic>)
                            .toList();
                      } else {
                        debugPrint('Geoapify error: ${response.statusCode}');
                        return [];
                      }
                    } catch (e) {
                      debugPrint('Geoapify exception: $e');
                      return [];
                    }
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(suggestion['formatted'] ?? ''),
                    );
                  },
                  onSelected: (suggestion) {
                    addressController.text = suggestion['formatted'] ?? '';
                    selectedProperties = suggestion;
                  },
                  builder: (context, textController, focusNode) {
                    // Sincronizamos el interno con el externo
                    textController.text = addressController.text;
                    textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: textController.text.length),
                    );

                    textController.addListener(() {
                      addressController.text = textController.text;
                    });

                    return TextFormField(
                      controller: textController, // ✅ usamos el del paquete
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Seleccione una dirección válida';
                        }
                        if (selectedProperties == null) {
                          return 'Seleccione una dirección de la lista';
                        }
                        return null;
                      },
                    );
                  },
                  // --- 👇 AÑADIMOS ESTE WIDGET PARA TRADUCIR "No items found" 👇 ---
                  emptyBuilder: (context) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('No se encontraron direcciones.'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: orgType,
                  items: const [
                    DropdownMenuItem(
                      value: 'DEPARTAMENTAL',
                      child: Text('Departamental'),
                    ),
                    DropdownMenuItem(
                      value: 'UNIFICADO',
                      child: Text('Unificado'),
                    ),
                  ],
                  onChanged: (val) =>
                      orgType = val ?? establishment.organizationType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de organización',
                    prefixIcon: Icon(Icons.category),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Seleccione un tipo' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final updated = establishment.copyWith(
                name: nameController.text.trim(),
                address: addressController.text.trim(),
                organizationType: orgType,
                latitude: selectedProperties?['lat']?.toDouble(),
                longitude: selectedProperties?['lon']?.toDouble(),
              );

              await controller.update(updated);
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
    EstablishmentsController controller,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar establecimiento'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este establecimiento? Esta acción no se puede deshacer.',
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
      await controller.delete(id);
    }
  }
}
