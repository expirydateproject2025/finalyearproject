import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notification channels and permissions
  Future<void> initialize() async {
    // Request permission for notifications
    await _requestPermissions();

    // Initialize time zones
    tz.initializeTimeZones();

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        print('Notification tapped: ${details.payload}');
      },
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Save device token to Firestore for the current user
    await _saveDeviceToken();
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestPermission();
    }
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'expiry_reminders',
      'Expiry Reminders',
      description: 'Notifications for product expiry dates',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_reminders',
            'Expiry Reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['productId'],
      );
    }
  }

  // Save device token to Firestore
  Future<void> _saveDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      User? currentUser = _auth.currentUser;

      if (token != null && currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('tokens')
            .doc(token)
            .set({
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  // Schedule a local notification for a product expiry
  Future<void> scheduleExpiryNotification({
    required String productId,
    required String productName,
    required DateTime expiryDate,
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get current date
    final now = DateTime.now();

    // Calculate notification dates
    final oneDay = expiryDate.subtract(const Duration(days: 1));
    final oneWeek = expiryDate.subtract(const Duration(days: 7));
    final oneMonth = expiryDate.subtract(const Duration(days: 30));

    // Schedule notifications only if the dates are in the future
    if (oneMonth.isAfter(now)) {
      await _scheduleNotification(
        id: int.parse('${productId.hashCode}1'),
        title: 'Expiry Reminder',
        body: '$productName will expire in one month',
        scheduledDate: oneMonth,
        productId: productId,
      );
    }

    if (oneWeek.isAfter(now)) {
      await _scheduleNotification(
        id: int.parse('${productId.hashCode}2'),
        title: 'Expiry Reminder',
        body: '$productName will expire in one week',
        scheduledDate: oneWeek,
        productId: productId,
      );
    }

    if (oneDay.isAfter(now)) {
      await _scheduleNotification(
        id: int.parse('${productId.hashCode}3'),
        title: 'Expiry Alert',
        body: '$productName will expire tomorrow',
        scheduledDate: oneDay,
        productId: productId,
      );
    }

    // Schedule notification for the day after expiry
    final afterExpiry = expiryDate.add(const Duration(days: 1));
    await _scheduleNotification(
      id: int.parse('${productId.hashCode}4'),
      title: 'Expired Product',
      body: '$productName has expired',
      scheduledDate: afterExpiry,
      productId: productId,
    );

    // Save the scheduled notifications to Firestore for tracking
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('products')
        .doc(productId)
        .update({
      'notificationsScheduled': true,
      'scheduledNotifications': {
        'oneMonth': oneMonth.millisecondsSinceEpoch,
        'oneWeek': oneWeek.millisecondsSinceEpoch,
        'oneDay': oneDay.millisecondsSinceEpoch,
        'afterExpiry': afterExpiry.millisecondsSinceEpoch,
      }
    });
  }

  // Helper method to schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String productId,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'expiry_reminders',
          'Expiry Reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: productId,
    );
  }

  // Cancel all notifications for a product
  Future<void> cancelProductNotifications(String productId) async {
    await _localNotifications.cancel(int.parse('${productId.hashCode}1'));
    await _localNotifications.cancel(int.parse('${productId.hashCode}2'));
    await _localNotifications.cancel(int.parse('${productId.hashCode}3'));
    await _localNotifications.cancel(int.parse('${productId.hashCode}4'));

    // Update Firestore
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('products')
          .doc(productId)
          .update({
        'notificationsScheduled': false,
        'scheduledNotifications': FieldValue.delete(),
      });
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}

// Firebase background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  print('Background message received: ${message.messageId}');
}