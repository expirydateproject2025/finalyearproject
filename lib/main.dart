import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'services/hybrid_notification_manager.dart';

final notificationManager = HybridNotificationManager();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await notificationManager.initialize();

    // Verify notification permissions
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    runApp(const MyApp());
  } catch (e) {
    print('Initialization error: $e');
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expiry Tracker',
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: AppRoutes.routes,
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) {
              if (FirebaseAuth.instance.currentUser != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  notificationManager.syncAllNotifications();
                });
                return AppRoutes.routes['/home']!(context);
              }
              return AppRoutes.routes['/']!(context);
            },
          );
        }
        return null;
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'Initialization Error',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Failed to initialize the app. Please restart.',
            style: TextStyle(color: Colors.grey[700]),
          ),
  ]
          ),
        ),
      ),
    );
  }
}