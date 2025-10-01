
import 'package:flutter/material.dart';

class ParkingScreen extends StatelessWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo (luego los vas a traer de Firestore)
    final cocheras = [
      {"id": "C1", "tipo": "Fija", "estado": "Disponible"},
      {"id": "C2", "tipo": "Libre", "estado": "Ocupada"},
      {"id": "C3", "tipo": "Tándem", "estado": "Reservada"},
      {"id": "C4", "tipo": "Fija", "estado": "Disponible"},
    ];

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Gestión de Cocheras",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: abrir formulario para agregar cochera
                },
                icon: const Icon(Icons.add),
                label: const Text("Agregar Cochera"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabla de cocheras
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("ID")),
                  DataColumn(label: Text("Tipo")),
                  DataColumn(label: Text("Estado")),
                  DataColumn(label: Text("Acciones")),
                ],
                rows: cocheras.map((cochera) {
                  return DataRow(
                    cells: [
                      DataCell(Text(cochera["id"]!)),
                      DataCell(Text(cochera["tipo"]!)),
                      DataCell(Text(cochera["estado"]!)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                // TODO: editar cochera
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // TODO: eliminar cochera
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
          ),
        ],
      ),
    );
  }
}
