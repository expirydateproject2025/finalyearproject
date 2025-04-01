
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import 'notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get products collection reference
  CollectionReference<Map<String, dynamic>> get _productsCollection {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(currentUserId).collection('products');
  }

  // Stream of all products
  Stream<List<Product>> getProducts() {
    return _productsCollection
        .orderBy('expiryDate')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Stream of expired products
  Stream<List<Product>> getExpiredProducts() {
    final now = Timestamp.fromDate(DateTime.now());
    return _productsCollection
        .where('expiryDate', isLessThan: now)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Stream of products expiring soon (within a week)
  Stream<List<Product>> getProductsExpiringSoon() {
    final now = DateTime.now();
    final oneWeekLater = Timestamp.fromDate(now.add(const Duration(days: 7)));
    final today = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    return _productsCollection
        .where('expiryDate', isGreaterThanOrEqualTo: today)
        .where('expiryDate', isLessThanOrEqualTo: oneWeekLater)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Add a new product
  Future<String> addProduct(Product product) async {
    try {
      // Add product to Firestore
      final docRef = await _productsCollection.add(product.toFirestore());

      // Schedule notifications for the product
      await _notificationService.scheduleExpiryNotification(
        productId: docRef.id,
        productName: product.name,
        expiryDate: product.expiryDate,
      );

      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  // Update an existing product
  Future<void> updateProduct(Product product) async {
    try {
      // Update product in Firestore
      await _productsCollection.doc(product.id).update(product.toFirestore());

      // Cancel existing notifications and schedule new ones
      await _notificationService.cancelProductNotifications(product.id);
      await _notificationService.scheduleExpiryNotification(
        productId: product.id,
        productName: product.name,
        expiryDate: product.expiryDate,
      );
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  // Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      // Cancel notifications for the product
      await _notificationService.cancelProductNotifications(productId);

      // Delete product from Firestore
      await _productsCollection.doc(productId).delete();
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }

  // Get a single product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _productsCollection.doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      rethrow;
    }
  }
}