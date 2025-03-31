import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String _expiryChannelId = 'expiry_channel';
  static const String _expiryChannelName = 'Expiry Notifications';
  static const String _expiryChannelDesc =
      'Notifications for product expiry dates';

  static int createNotificationId(String productId, int offsetDays) {
    return productId.hashCode + offsetDays;
  }

  Future<void> initialize() async {
    try {
      tz_data.initializeTimeZones();
      final location = tz.getLocation('America/New_York');
      tz.setLocalLocation(location);

      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('Notification tapped: ${response.payload}');
        },
      );

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _expiryChannelId,
        _expiryChannelName,
        description: _expiryChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Request permissions for iOS
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      print('Local notifications initialized');
    } catch (e) {
      print('Error initializing local notifications: $e');
      rethrow;
    }
  }

  Future<void> scheduleExpiryNotifications(
      String productId, String productName, DateTime expiryDate) async {
    try {
      await cancelProductNotifications(productId);

      final now = DateTime.now();
      final expiryDateTime = tz.TZDateTime.from(expiryDate, tz.local);

      if (expiryDate.isBefore(now)) {
        await _scheduleExpiredNotification(productId, productName);
        return;
      }

      // Schedule notifications at different intervals
      await _scheduleNotificationIfNeeded(
          productId, productName, expiryDateTime, -30, 'will expire in 30 days', 'info');
      await _scheduleNotificationIfNeeded(
          productId, productName, expiryDateTime, -7, 'will expire in 7 days', 'info');
      await _scheduleNotificationIfNeeded(
          productId, productName, expiryDateTime, -3, 'will expire in 3 days', 'warning');
      await _scheduleNotificationIfNeeded(
          productId, productName, expiryDateTime, -1, 'will expire tomorrow', 'warning');
      await _scheduleNotificationIfNeeded(
          productId, productName, expiryDateTime, 0, 'expires today', 'warning');
      await _scheduleNotificationIfNeeded(
          productId, productName, expiryDateTime, 1, 'has expired', 'expiry');

      print('Scheduled notifications for $productName');
    } catch (e) {
      print('Error scheduling expiry notifications: $e');
      rethrow;
    }
  }

  Future<void> _scheduleNotificationIfNeeded(
      String productId,
      String productName,
      tz.TZDateTime expiryDate,
      int offsetDays,
      String messageText,
      String type) async {
    final notificationTime = expiryDate.add(Duration(days: offsetDays));

    if (notificationTime.isAfter(tz.TZDateTime.now(tz.local))) {
      final notificationId = createNotificationId(productId, offsetDays);

      String title;
      String emoji;

      switch (type) {
        case 'expiry':
          title = 'Product Expired';
          emoji = '⚠️';
          break;
        case 'warning':
          title = 'Expiry Alert';
          emoji = '⚠️';
          break;
        case 'info':
        default:
          title = 'Expiry Reminder';
          emoji = '📅';
          break;
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        '$emoji $productName $messageText',
        notificationTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _expiryChannelId,
            _expiryChannelName,
            channelDescription: _expiryChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            color: _getColorForType(type),
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        // Corrected parameter
      );

      print('Scheduled $type notification for $productName at $notificationTime');
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _expiryChannelId,
          _expiryChannelName,
          channelDescription: _expiryChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _scheduleExpiredNotification(String productId, String productName) async {
    await showImmediateNotification(
      title: 'Product Expired',
      body: '⚠️ $productName has expired',
      payload: 'product:$productId',
    );
  }

  Future<void> cancelProductNotifications(String productId) async {
    try {
      final offsets = [-30, -7, -3, -1, 0, 1];
      for (final offset in offsets) {
        final notificationId = createNotificationId(productId, offset);
        await _flutterLocalNotificationsPlugin.cancel(notificationId);
      }
      print('Cancelled notifications for $productId');
    } catch (e) {
      print('Error cancelling product notifications: $e');
      rethrow;
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('Cancelled all notifications');
    } catch (e) {
      print('Error cancelling all notifications: $e');
      rethrow;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'expiry':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  Future<void> syncExpiryNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await cancelAllNotifications();

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in productsSnapshot.docs) {
        final product = doc.data();
        if (product['expiryDate'] != null) {
          final expiryDate = (product['expiryDate'] as Timestamp).toDate();
          await scheduleExpiryNotifications(
            doc.id,
            product['name'] ?? 'Product',
            expiryDate,
          );
        }
      }

      print('Synced ${productsSnapshot.docs.length} products');
    } catch (e) {
      print('Error syncing expiry notifications: $e');
      rethrow;
    }
  }
}
