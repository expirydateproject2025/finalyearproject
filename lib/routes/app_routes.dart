import 'package:flutter/material.dart';
import 'package:expirydatetracker/screens/auth/login_screen.dart';
import 'package:expirydatetracker/screens/home_screen.dart';
import 'package:expirydatetracker/screens/auth/signup_screen.dart';
import 'package:expirydatetracker/screens/add_product_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const LoginScreen(),
    '/home': (context) => const HomeScreen(),
    '/signup': (context) => const SignupScreen(),
    '/AddProduct': (context) => const AddProductPage(),
  };

  // Optional: Add this method if you want to handle auth routing in AppRoutes
  static Widget getInitialScreen() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}