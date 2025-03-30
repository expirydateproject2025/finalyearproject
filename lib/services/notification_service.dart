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

    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'unread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'unread': false});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
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