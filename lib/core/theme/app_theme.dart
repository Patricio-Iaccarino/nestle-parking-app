import 'package:flutter/material.dart';

final List<Color> colorList = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.purple,
  Colors.orange,
  Colors.pink,
  Colors.teal,
  Colors.cyan,
];

class AppTheme {
  final bool isDark;
  final int selectedColor;

  AppTheme({required this.isDark, required this.selectedColor});

  ThemeData getTheme() {
    return ThemeData(
      colorSchemeSeed: colorList[selectedColor],
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
  }

}