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

    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
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
              content: Text('Error: ${error.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });

    return Scaffold(
      // Fondo general gris claro para que la tarjeta resalte
      backgroundColor: const Color(0xFFF0F2F5), 
      body: Stack(
        children: [
          // --- FONDO DECORATIVO ---
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: const BoxDecoration(
              color: Color(0xFFD91E28), // Rojo Nestlé
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          
          // --- CONTENIDO CENTRADO ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- LOGO GRANDE Y LIMPIO ---
                  // Quitamos el CircleAvatar para que el logo respire
                  Container(
                    padding: const EdgeInsets.all(12), // Un poco de margen interno
                    decoration: BoxDecoration(
                      color: Colors.white, // Fondo blanco para el logo
                      shape: BoxShape.circle, // Forma circular
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    // Aumentamos el tamaño del logo
                    height: 120, 
                    width: 120,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0), // Margen interno del logo
                      child: Image.asset(
                        'assets/images/nestle_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // --- TARJETA PRINCIPAL ---
                  SizedBox(
                    width: 400,
                    child: Card(
                      elevation: 10, // Sombra más pronunciada
                      shadowColor: Colors.black.withOpacity(0.1),
                      color: Colors.white, // ✨ FONDO BLANCO PURO
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Bienvenido',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sistema de Gestión de Cocheras',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Spinner o Formulario
                            if (authState.isLoading)
                              const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(
                                  color: Color(0xFFD91E28),
                                ),
                              )
                            else
                              const LoginForm(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  // Footer sutil
                  const Text(
                    '© 2025 Nestlé - Grupo 3 ORT',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}