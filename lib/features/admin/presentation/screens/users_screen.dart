import 'package:flutter/material.dart';


class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Usuarios",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Botón para agregar un usuario de prueba
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add),
            label: const Text("Agregar Usuario"),
          ),

          const SizedBox(height: 20),

          // Lista de usuarios en tiempo real
        ],
      ),
    );
  }
}
