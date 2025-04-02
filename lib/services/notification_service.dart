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
  bool _isInitialized = false;

  // Initialize notification channels and permissions
  Future<void> initialize() async {
    // Prevent duplicate initialization
    if (_isInitialized) return;

    try {
      // Initialize time zones first
      tz.initializeTimeZones();

      // Requ  est permission for notifications
      await _requestPermissions();

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

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Save device token to Firestore for the current user
      await _saveDeviceToken();

      _isInitialized = true;
      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      // No need for Android permission request here
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'expiry_reminders',
        'Expiry Reminders',
        description: 'Notifications for product expiry dates',
        importance: Importance.high,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      } else {
        print('Android plugin is null when creating notification channel.');
      }
    } catch (e) {
      print('Error creating notification channel: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    try {
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
    } catch (e) {
      print('Error handling foreground message: $e');
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
        print('Device token saved successfully: $token');
      } else {
        print('Failed to save token: token=$token, user=${currentUser?.uid}');
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
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Cannot schedule notification: User not authenticated');
        return;
      }

      // Get current date
      final now = DateTime.now();

      // Calculate notification dates
      final oneDay = expiryDate.subtract(const Duration(days: 1));
      final oneWeek = expiryDate.subtract(const Duration(days: 7));
      final oneMonth = expiryDate.subtract(const Duration(days: 30));

      print('Scheduling notifications for product: $productName (ID: $productId)');
      print('Expiry date: $expiryDate');

      // Generate safe IDs using modulo to prevent integer overflow
      final baseId = productId.hashCode % 100000;

      // Schedule notifications only if the dates are in the future
      if (oneMonth.isAfter(now)) {
        await _scheduleNotification(
          id: baseId + 1,
          title: 'Expiry Reminder',
          body: '$productName will expire in one month',
          scheduledDate: oneMonth,
          productId: productId,
        );
        print('Scheduled one month notification for $oneMonth');
      }

      if (oneWeek.isAfter(now)) {
        await _scheduleNotification(
          id: baseId + 2,
          title: 'Expiry Reminder',
          body: '$productName will expire in one week',
          scheduledDate: oneWeek,
          productId: productId,
        );
        print('Scheduled one week notification for $oneWeek');
      }

      if (oneDay.isAfter(now)) {
        await _scheduleNotification(
          id: baseId + 3,
          title: 'Expiry Alert',
          body: '$productName will expire tomorrow',
          scheduledDate: oneDay,
          productId: productId,
        );
        print('Scheduled one day notification for $oneDay');
      }

      // Schedule notification for the day after expiry
      final afterExpiry = expiryDate.add(const Duration(days: 1));
      await _scheduleNotification(
        id: baseId + 4,
        title: 'Expired Product',
        body: '$productName has expired',
        scheduledDate: afterExpiry,
        productId: productId,
      );
      print('Scheduled after expiry notification for $afterExpiry');

      // Save the scheduled notifications to Firestore for tracking
      final docRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('products')
          .doc(productId);

      final docSnapshot = await docRef.get();

      final notificationData = {
        'notificationsScheduled': true,
        'scheduledNotifications': {
          'oneMonth': oneMonth.millisecondsSinceEpoch,
          'oneWeek': oneWeek.millisecondsSinceEpoch,
          'oneDay': oneDay.millisecondsSinceEpoch,
          'afterExpiry': afterExpiry.millisecondsSinceEpoch,
        }
      };

      if (docSnapshot.exists) {
        await docRef.update(notificationData);
      } else {
        await docRef.set(notificationData, SetOptions(merge: true));
      }

      print('Notification data saved to Firestore');
    } catch (e) {
      print('Error scheduling expiry notifications: $e');
      rethrow;
    }
  }

  // Helper method to schedule a single notification
  // Helper method to schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String productId,
  }) async {
    try {
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
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: productId,
      );
      print('Scheduled notification ID $id for $scheduledDate successfully');
    } catch (e) {
      print('Error scheduling notification: $e');
      rethrow;
    }
  }

  // Cancel all notifications for a product
  Future<void> cancelProductNotifications(String productId) async {
    try {
      final baseId = productId.hashCode % 100000;

      await _localNotifications.cancel(baseId + 1);
      await _localNotifications.cancel(baseId + 2);
      await _localNotifications.cancel(baseId + 3);
      await _localNotifications.cancel(baseId + 4);
      print('Cancelled notifications for product ID: $productId');

      // Update Firestore
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final docRef = _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('products')
            .doc(productId);

        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          await docRef.update({
            'notificationsScheduled': false,
            'scheduledNotifications': FieldValue.delete(),
          });
          print('Updated Firestore for cancelled notifications');
        }
      }
    } catch (e) {
      print('Error cancelling product notifications: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('Cancelled all notifications');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }
}