import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2F80ED); // Blue
  static const Color secondaryColor = Color(0xFFFFFFFF); // White
  static const Color lightBackgroundColor = Color(0xFFF5F5F5); // Light gray
  static const Color accentColor = Colors.orange; // Accent color

  static final theme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black), // Equivalent to bodyText1
      bodyMedium: TextStyle(color: Colors.black54), // Equivalent to bodyText2
      headlineLarge: TextStyle(color: Colors.white, fontSize: 20), // Equivalent to headline6
    ),
  );
}