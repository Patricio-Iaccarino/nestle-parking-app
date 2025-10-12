// import 'package:cocheras_nestle_web/features/garages/domain/models/garage_location.dart';
// import 'package:flutter/material.dart';

// class GarageDetailScreen extends StatelessWidget {
//   final Garage garage;

//   const GarageDetailScreen({super.key, required this.garage});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(garage.name)),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('📍 Dirección: ${garage.address}'),
//             Text('👥 Capacidad: ${garage.capacity}'),
//             Text('🚗 Reservas actuales: ${garage.currentReservations}'),
//             Text('🕒 Creado: ${garage.createdAt}'),
//             Text('📍 Lat: ${garage.lat}, Lng: ${garage.lng}'),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.edit),
//               label: const Text('Editar cochera'),
//               onPressed: () {
//                 // Navegar a la pantalla de edición
                
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
