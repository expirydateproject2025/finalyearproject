import 'package:flutter/material.dart';
import 'package:expirydatetracker/screens/auth/login_screen.dart';
import 'package:expirydatetracker/screens/home_screen.dart';
import 'package:expirydatetracker/screens/auth/signup_screen.dart';
import 'package:expirydatetracker/screens/add_product_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expirydatetracker/navigation/main_wrapper.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const LoginScreen(),
    '/home': (context) => const MainWrapper(),
    '/signup': (context) => const SignupScreen(),
  };

  static Widget getInitialScreen() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? const MainWrapper() : const LoginScreen();
  }
}
