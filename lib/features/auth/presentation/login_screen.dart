import 'package:cocheras_nestle_web/features/auth/presentation/auth_controller.dart';
import 'package:cocheras_nestle_web/features/auth/presentation/widgets/login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    // (Tu ref.listen para errores y navegación está perfecto)
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          // Asumiendo que el SuperAdmin no tiene dashboard y va a otra ruta
          if (user != null) {
            if (user.role == 'superadmin') {
              context.go('/establishments');
            } else {
              context.go('/dashboard');
            }
          }
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar sesión: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    });

    return Scaffold(
      // --- 👇 CAMBIO ESTÉTICO 1: Fondo con Gradiente ---
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[100]!,
              Colors.grey[300]!,
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 400,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 👇 CAMBIO ESTÉTICO 2: Ícono más profesional ---
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFD91E28), // Tu Nestlé Red
                      child: Icon(
                        Icons.lock_outline, // Un ícono de login
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    // (También podrías usar un Image.asset('assets/nestle_logo.png') si tienes el logo)
                    // 
                    
                    const SizedBox(height: 24),
                    const Text(
                      'Cocheras Nestlé',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inicia sesión para continuar',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 28),
                    if (authState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      )
                    else
                      const LoginForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}