//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Screen')),
      body: Placeholder()
    );
  }
}

// class _FireStoreTest extends StatelessWidget {
//   const _FireStoreTest();

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//       future: FirebaseFirestore.instance.collection('tests').add({
//         'mensaje': 'Hola Firebase!',
//         'timestamp': DateTime.now(),
//       }),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.done) {
//           return const Text('Documento creado en Firestore ✅');
//         }
//         return const CircularProgressIndicator();
//       },
//     );
//   }
// }
