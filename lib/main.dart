import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/notification_page.dart';
import 'services/notification_service.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

/// Background message handler (MUST be top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().initialize();
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();

    // Initialize notification service
    await NotificationService().initialize();

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Initialization error: $e');
    runApp(const ErrorApp(errorMessage: 'Failed to initialize Firebase.'));
  }
}

Future<void> _initializeFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request notification permissions
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint("User granted notifications permission");

    // Foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Got a message whilst in the foreground!");
      debugPrint("Message data: ${message.data}");

      if (message.notification != null) {
        debugPrint("Message also contained a notification: ${message.notification}");
      }
    });

    // Background message handling
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // When user taps on notification to open app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification clicked: ${message.messageId}");
    });

    // Get FCM token
    String? token = await messaging.getToken();
    debugPrint("FCM Token: $token");
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotificationPage();
  }
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

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
                errorMessage,
                style: TextStyle(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}