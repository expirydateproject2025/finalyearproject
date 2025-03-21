import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFB6F06);  // Orange
  static const secondary = Color(0xFF4DBDEE); // Gray
  static const background = Color(0xFF070625);
  static const textDark = Color(0xFFDA4E00);
  static const textLight = Color(0xFFF35F06);
}

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF082969), // Sky blue
              Color(0xFF070625),  // Blue color at the end
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.4, 1.0],
          ),
        ),
      ),
    );
  }
}