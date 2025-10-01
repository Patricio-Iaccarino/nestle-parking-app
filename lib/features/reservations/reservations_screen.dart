import 'package:flutter/material.dart';

class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo (luego los vas a traer de Firestore)
    final reservas = [
      {
        "usuario": "Juan Pérez",
        "cochera": "C1",
        "fecha": "30/09/2025",
        "estado": "Activa",
      },
      {
        "usuario": "María López",
        "cochera": "C2",
        "fecha": "29/09/2025",
        "estado": "Finalizada",
      },
      {
        "usuario": "Carlos Díaz",
        "cochera": "C3",
        "fecha": "30/09/2025",
        "estado": "Cancelada",
      },
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
                "Gestión de Reservas",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: abrir formulario manual de reserva
                },
                icon: const Icon(Icons.add),
                label: const Text("Nueva Reserva"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filtros rápidos
          Row(
            children: [
              DropdownButton<String>(
                value: "Todas",
                items: const [
                  DropdownMenuItem(value: "Todas", child: Text("Todas")),
                  DropdownMenuItem(value: "Activa", child: Text("Activas")),
                  DropdownMenuItem(
                    value: "Finalizada",
                    child: Text("Finalizadas"),
                  ),
                  DropdownMenuItem(
                    value: "Cancelada",
                    child: Text("Canceladas"),
                  ),
                ],
                onChanged: (value) {
                  // TODO: aplicar filtro
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Buscar por usuario...",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    // TODO: filtrar reservas
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabla de reservas
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Usuario")),
                  DataColumn(label: Text("Cochera")),
                  DataColumn(label: Text("Fecha")),
                  DataColumn(label: Text("Estado")),
                  DataColumn(label: Text("Acciones")),
                ],
                rows: reservas.map((reserva) {
                  return DataRow(
                    cells: [
                      DataCell(Text(reserva["usuario"]!)),
                      DataCell(Text(reserva["cochera"]!)),
                      DataCell(Text(reserva["fecha"]!)),
                      DataCell(Text(reserva["estado"]!)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info, color: Colors.blue),
                              onPressed: () {
                                // TODO: ver detalle de la reserva
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                // TODO: cancelar reserva
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
