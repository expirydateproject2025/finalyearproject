import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_page.dart';
import 'screens/add_product_page.dart';
import 'screens/profile_page.dart';
import 'widgets/about_page.dart';

// Services
import 'services/notification_service.dart';

// Routes
import 'routes/app_routes.dart';
import 'package:expirydatetracker/navigation/main_wrapper.dart';

// Theme
import 'theme/app_theme.dart';

// Models/Providers
import 'models/ProductProvider.dart';
import 'package:expirydatetracker/navigation/bottom_nav_controller.dart';

/// Background message handler (MUST be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();

    // Initialize notification service
    await NotificationService().initialize();

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Initialization error: $e');
    runApp(ErrorApp(errorMessage: 'Failed to initialize: $e'));
  }
}

Future<void> _initializeFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint("User granted notifications permission");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message: ${message.data}");
      if (message.notification != null) {
        debugPrint("Notification: ${message.notification}");
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification clicked: ${message.messageId}");
    });

    String? token = await messaging.getToken();
    debugPrint("FCM Token: $token");
  } else {
    debugPrint("User denied notifications permission: ${settings.authorizationStatus}");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavController()),
      ],
      child: MaterialApp(
        title: 'Expiry Date Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: AppRoutes.getInitialScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const MainWrapper(),
          '/notifications': (context) => const NotificationPage(),
          '/profile': (context) => const ProfilePage(),
          '/about': (context) => const AboutPage(),
        },
      ),
    );
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}