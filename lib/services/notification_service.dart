import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
  }) async {
    if (userId == null) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Created cloud notification: $title');
    } catch (e) {
      print('Error creating notification: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getNotifications() {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createExpiryNotification(String productName, int daysUntilExpiry) async {
    String message;
    String type;

    if (daysUntilExpiry <= 0) {
      message = '$productName has expired!';
      type = 'expiry';
    } else if (daysUntilExpiry <= 3) {
      message = '$productName will expire in $daysUntilExpiry days';
      type = 'warning';
    } else {
      message = '$productName will expire in $daysUntilExpiry days';
      type = 'info';
    }

    await createNotification(
      title: 'Product Expiry Alert',
      message: message,
      type: type,
    );
  }
}