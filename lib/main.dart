import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_routes.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'screens/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expiry Date Notification',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme, // Use the theme defined in AppTheme
      initialRoute: '/login', // Default route to show first
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfilePage(),
        ...AppRoutes.routes, // Spread the routes defined in AppRoutes
      },

    );

  }
}



