import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150, // Increased for better visibility
      width: 150, // Increased for better visibility
      // Add padding inside the container
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15), // Optional for rounded image corners
        child: Image.asset(
          'assets/images/login.jpg', // Your image file path
          fit: BoxFit.contain, // Ensures the image fits inside without distortion
        ),
      ),
    );
  }
}
