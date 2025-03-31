import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';

class HybridNotificationManager {
  final NotificationService _cloudService = NotificationService();
  final LocalNotificationService _localService = LocalNotificationService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      // Initialize local notifications
      await _localService.initialize();

      // Request permission for FCM (Firebase Cloud Messaging)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('Notification permissions granted: ${settings.authorizationStatus}');

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Setup FCM background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle FCM messages when the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.messageId}');
        _handleRemoteMessage(message);
      });

      // Handle FCM message tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Opened app from notification: ${message.messageId}');
        // Handle navigation to specific screen
      });

      // Handle initial notification when app is launched
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('App launched from notification: ${initialMessage.messageId}');
      }
    } catch (e) {
      print('Notification initialization error: $e');
      rethrow;
    }
  }

  Future<void> addProductWithNotifications({
    required String productId,
    required String productName,
    required DateTime expiryDate,
  }) async {
    try {
      final now = DateTime.now();
      final daysUntilExpiry = expiryDate.difference(now).inDays;

      print('Adding notifications for $productName (expires in $daysUntilExpiry days)');

      // Create cloud notification if applicable
      if (daysUntilExpiry <= 30) {
        await _cloudService.createExpiryNotification(productName, daysUntilExpiry);
      }

      // Schedule local notifications
      await _localService.scheduleExpiryNotifications(productId, productName, expiryDate);
    } catch (e) {
      print('Error adding product notifications: $e');
      rethrow;
    }
  }

  Future<void> updateProductNotifications({
    required String productId,
    required String productName,
    required DateTime expiryDate,
  }) async {
    try {
      print('Updating notifications for $productId');
      await _localService.cancelProductNotifications(productId);
      await addProductWithNotifications(
        productId: productId,
        productName: productName,
        expiryDate: expiryDate,
      );
    } catch (e) {
      print('Error updating product notifications: $e');
      rethrow;
    }
  }

  Future<void> deleteProductNotifications(String productId) async {
    try {
      print('Deleting notifications for $productId');
      await _localService.cancelProductNotifications(productId);
    } catch (e) {
      print('Error deleting product notifications: $e');
      rethrow;
    }
  }

  Future<void> syncAllNotifications() async {
    try {
      print('Syncing all notifications');
      await _localService.syncExpiryNotifications();
    } catch (e) {
      print('Error syncing notifications: $e');
      rethrow;
    }
  }

  void _handleRemoteMessage(RemoteMessage message) {
    try {
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        _localService.showImmediateNotification(
          title: notification.title ?? 'Expiry Alert',
          body: notification.body ?? 'Product expiry notification',
          payload: data.toString(),
        );
      }
    } catch (e) {
      print('Error handling remote message: $e');
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    // You can initialize your services here if needed
    await Firebase.initializeApp();
    final localService = LocalNotificationService();
    await localService.initialize();

    if (message.notification != null) {
      localService.showImmediateNotification(
        title: message.notification?.title ?? 'Background Alert',
        body: message.notification?.body ?? 'Background notification',
        payload: message.data.toString(),
      );
    }
  }
}