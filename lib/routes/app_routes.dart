import 'package:flutter/material.dart';
import 'package:expirydatetracker/screens/auth/login_screen.dart';
import 'package:expirydatetracker/screens/home_screen.dart';
import 'package:expirydatetracker/screens/auth/signup_screen.dart';
import 'package:expirydatetracker/screens/add_product_page.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const LoginScreen(),
    '/home': (context) => const HomeScreen(),
    '/signup': (context) => const SignupScreen(),
    '/AddProduct': (context) => const AddProductPage(),
  };
}