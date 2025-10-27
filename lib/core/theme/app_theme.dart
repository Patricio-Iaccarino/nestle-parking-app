import 'package:flutter/material.dart';

class AppTheme {
  final bool isDark;
  AppTheme({required this.isDark});

  ThemeData getTheme() {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF005792), // Azul corporativo de Nestlé
        primary: const Color(0xFF005792), 
        secondary: const Color(
          0xFFD91E28,
        ), // Rojo de Nestlé para acentos (ej. botones de borrar)
        brightness: Brightness.light,
      ),
      // Define el estilo de los botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(
            0xFF005792,
          ), // Botones con el azul primario
          foregroundColor: Colors.white, // Texto blanco en los botones
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      // Define el estilo de los campos de texto
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.all(8),
      ),

      useMaterial3: true,
    );
  }
}
