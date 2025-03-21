import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF2F80ED); // Orange
  static const secondaryColor = Color(0xFFFFFFFF); // Gray


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

