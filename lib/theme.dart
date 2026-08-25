import 'package:flutter/material.dart';

class AppTheme {
  // Petronas Brand Colors
  static const Color petronasGreen = Color(0xFF00A19C);
  static const Color petronasYellow = Color(0xFFFFD100);
  static const Color petronasBlue = Color(0xFF002244); // Dark Navy Blue
  static const Color black = Colors.black;
  static const Color white = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: petronasGreen,
      scaffoldBackgroundColor: white,
      colorScheme: const ColorScheme.light(
        primary: petronasGreen,
        secondary: petronasYellow,
        tertiary: petronasBlue,
        surface: white,
        onPrimary: white,
        onSecondary: black,
        onSurface: black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: petronasGreen,
        foregroundColor: white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: petronasGreen,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: petronasBlue, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: petronasBlue, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: black),
        bodyMedium: TextStyle(color: black),
      ),
      useMaterial3: true,
    );
  }
}
