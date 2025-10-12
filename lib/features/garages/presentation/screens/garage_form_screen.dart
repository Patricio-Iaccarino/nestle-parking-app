
import 'package:cocheras_nestle_web/features/garages/domain/models/garage_location_model.dart';
import 'package:cocheras_nestle_web/features/garages/providers/garage_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



class GarageFormScreen extends ConsumerStatefulWidget {
  final GarageLocation? garage; // null => modo creación

  const GarageFormScreen({super.key, this.garage});

  @override
  ConsumerState<GarageFormScreen> createState() => _GarageFormScreenState();
}

class _GarageFormScreenState extends ConsumerState<GarageFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _capacityController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final garage = widget.garage;
    _nameController = TextEditingController(text: garage?.name ?? '');
    _addressController = TextEditingController(text: garage?.address ?? '');
    _capacityController =
        TextEditingController(text: garage?.capacity.toString() ?? '');
    _latController =
        TextEditingController(text: garage?.lat.toString() ?? '');
    _lngController =
        TextEditingController(text: garage?.lng.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _saveGarage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(garageRepositoryProvider);

      final garage = GarageLocation(
        id: widget.garage?.id ?? '', // si es nuevo, Firestore generará uno
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        capacity: int.tryParse(_capacityController.text) ?? 0,
        lat: double.tryParse(_latController.text) ?? 0.0,
        lng: double.tryParse(_lngController.text) ?? 0.0,
        adminId: widget.garage?.adminId,
        adminIds: widget.garage?.adminIds ?? [],
        createdAt: widget.garage?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        currentReservations: widget.garage?.currentReservations ?? 0,
        assignedUsers: widget.garage?.assignedUsers ?? [],
        assignedSectors: widget.garage?.assignedSectors ?? [],
      );

      await repository.saveGarage(garage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cochera guardada correctamente')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.garage != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Cochera' : 'Nueva Cochera'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo obligatorio' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo obligatorio' : null,
              ),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacidad'),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: 'Latitud'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(labelText: 'Longitud'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGarage,
                icon: const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
