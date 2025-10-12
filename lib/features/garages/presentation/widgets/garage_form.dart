// import 'package:flutter/material.dart';
// import '../../domain/models/garage_location.dart';

// class GarageForm extends StatefulWidget {
//   final Garage? initialGarage;
//   final void Function(Garage garage) onSubmit;

//   const GarageForm({super.key, this.initialGarage, required this.onSubmit});

//   @override
//   State<GarageForm> createState() => _GarageFormState();
// }

// class _GarageFormState extends State<GarageForm> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _addressController;
//   late TextEditingController _capacityController;
//   late TextEditingController _latController;
//   late TextEditingController _lngController;

//   @override
//   void initState() {
//     super.initState();
//     final g = widget.initialGarage;
//     _nameController = TextEditingController(text: g?.name ?? '');
//     _addressController = TextEditingController(text: g?.address ?? '');
//     _capacityController = TextEditingController(text: g?.capacity.toString() ?? '');
//     _latController = TextEditingController(text: g?.lat.toString() ?? '');
//     _lngController = TextEditingController(text: g?.lng.toString() ?? '');
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _addressController.dispose();
//     _capacityController.dispose();
//     _latController.dispose();
//     _lngController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Form(
//       key: _formKey,
//       child: ListView(
//         children: [
//           TextFormField(
//             controller: _nameController,
//             decoration: const InputDecoration(labelText: 'Nombre'),
//             validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
//           ),
//           TextFormField(
//             controller: _addressController,
//             decoration: const InputDecoration(labelText: 'Dirección'),
//             validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
//           ),
//           TextFormField(
//             controller: _capacityController,
//             decoration: const InputDecoration(labelText: 'Capacidad'),
//             keyboardType: TextInputType.number,
//             validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
//           ),
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: _latController,
//                   decoration: const InputDecoration(labelText: 'Latitud'),
//                   keyboardType: TextInputType.number,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: TextFormField(
//                   controller: _lngController,
//                   decoration: const InputDecoration(labelText: 'Longitud'),
//                   keyboardType: TextInputType.number,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           ElevatedButton.icon(
//             icon: const Icon(Icons.save),
//             label: const Text('Guardar'),
//             onPressed: () {
//               if (_formKey.currentState!.validate()) {
//                 final garage = Garage(
//                   id: widget.initialGarage?.id ?? '',
//                   name: _nameController.text,
//                   address: _addressController.text,
//                   capacity: int.tryParse(_capacityController.text) ?? 0,
//                   lat: double.tryParse(_latController.text) ?? 0,
//                   lng: double.tryParse(_lngController.text) ?? 0,
//                   createdAt: widget.initialGarage?.createdAt ?? DateTime.now(),
//                   updatedAt: DateTime.now(),
//                   adminId: widget.initialGarage?.adminId?? [],
//                   currentReservations: widget.initialGarage?.currentReservations ?? 0,
//                   assignedUsers: widget.initialGarage?.assignedUsers ?? [],
//                   asignedSectors: widget.initialGarage?.asignedSectors ?? [],
//                 );
//                 widget.onSubmit(garage);
//               }
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
