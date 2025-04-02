import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Product {
  final String? id;
  final String name;
  final DateTime expiryDate;
  final String category;
  final String? reminder;
  final int? quantity;
  final String? photoUrl;
  final String? barcode;
  final String? notes;
  final String? userId;
  final bool notificationsScheduled;
  final Map<String, dynamic>? scheduledNotifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    required this.expiryDate,
    required this.category,
    this.reminder,
    this.quantity,
    this.photoUrl,
    this.barcode,
    this.notes,
    this.userId,
    this.notificationsScheduled = false,
    this.scheduledNotifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    // Get current user ID if not provided
    String? currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;

    return {
      'name': name,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'category': category,
      'reminder': reminder,
      'quantity': quantity ?? 1,
      'photoUrl': photoUrl,
      'barcode': barcode,
      'notes': notes,
      'userId': currentUserId,
      'notificationsScheduled': notificationsScheduled,
      'scheduledNotifications': scheduledNotifications,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()), // Always update the timestamp
    };
  }

  // Alternative name for toFirestore for compatibility
  Map<String, dynamic> toMap() => toFirestore();

  // Create from Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle missing or invalid data with defaults
    return Product(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Product',
      expiryDate: data['expiryDate'] is Timestamp
          ? (data['expiryDate'] as Timestamp).toDate()
          : DateTime.now(),
      category: data['category'] ?? 'Uncategorized',
      reminder: data['reminder'],
      quantity: data['quantity'] is int ? data['quantity'] : 1,
      photoUrl: data['photoUrl'],
      barcode: data['barcode'],
      notes: data['notes'],
      userId: data['userId'],
      notificationsScheduled: data['notificationsScheduled'] ?? false,
      scheduledNotifications: data['scheduledNotifications'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Copy with method
  Product copyWith({
    String? id,
    String? name,
    DateTime? expiryDate,
    String? category,
    String? reminder,
    int? quantity,
    String? photoUrl,
    String? barcode,
    String? notes,
    String? userId,
    bool? notificationsScheduled,
    Map<String, dynamic>? scheduledNotifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      expiryDate: expiryDate ?? this.expiryDate,
      category: category ?? this.category,
      reminder: reminder ?? this.reminder,
      quantity: quantity ?? this.quantity,
      photoUrl: photoUrl ?? this.photoUrl,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      notificationsScheduled: notificationsScheduled ?? this.notificationsScheduled,
      scheduledNotifications: scheduledNotifications ?? this.scheduledNotifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update when copying
    );
  }

  // Expiry status helpers
  bool get isExpired => DateTime.now().isAfter(expiryDate);

  int get daysRemaining {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    return difference < 0 ? 0 : difference;
  }

  String get expiryStatus {
    if (isExpired) {
      return 'Expired';
    } else if (daysRemaining <= 1) {
      return 'Expires Today/Tomorrow';
    } else if (daysRemaining <= 7) {
      return 'Expires This Week';
    } else if (daysRemaining <= 30) {
      return 'Expires This Month';
    } else {
      return 'Valid';
    }
  }

  // Get user-specific collection reference - using structure from first version
  static CollectionReference<Map<String, dynamic>> getUserProductsCollection(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('products');
  }

  // Alternative collection reference - using structure from second version
  static CollectionReference<Map<String, dynamic>> getProductsCollection(String userId) {
    return FirebaseFirestore.instance
        .collection('products')
        .doc(userId)
        .collection('items');
  }

  // Get current user's collection reference - using structure from first version
  static CollectionReference<Map<String, dynamic>> get currentUserProductsCollection {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return getUserProductsCollection(userId);
  }

  // Save product to Firestore - using structure from first version
  Future<DocumentReference> save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final collection = getUserProductsCollection(userId);

    // If the product has an ID, update it, otherwise create a new one
    if (id != null) {
      await collection.doc(id).update(toFirestore());
      return collection.doc(id);
    } else {
      return await collection.add(toFirestore());
    }
  }

  // Alternative save method - using structure from second version
  Future<DocumentReference> saveToProductsCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to save a product');
    }

    try {
      final productsRef = getProductsCollection(user.uid);

      // If the product has an ID, update it, otherwise create a new one
      if (id != null) {
        await productsRef.doc(id).update(toFirestore());
        return productsRef.doc(id);
      } else {
        return await productsRef.add(toFirestore());
      }
    } catch (e) {
      throw Exception('Failed to save product: $e');
    }
  }

  // Delete product method
  Future<void> delete() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (id == null) {
      throw Exception('Cannot delete a product without an ID');
    }

    final collection = getUserProductsCollection(userId);
    await collection.doc(id).delete();
  }

  // Fetch products by expiry status
  static Future<List<Product>> getProductsByExpiryStatus(String status) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final collection = getUserProductsCollection(userId);

    // Define query based on status
    Query query;
    final now = DateTime.now();

    switch (status) {
      case 'Expired':
        query = collection.where('expiryDate', isLessThan: Timestamp.fromDate(now));
        break;
      case 'Expires Today/Tomorrow':
        final tomorrow = now.add(const Duration(days: 1));
        query = collection
            .where('expiryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(tomorrow));
        break;
      case 'Expires This Week':
        final nextWeek = now.add(const Duration(days: 7));
        final tomorrow = now.add(const Duration(days: 1));
        query = collection
            .where('expiryDate', isGreaterThan: Timestamp.fromDate(tomorrow))
            .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(nextWeek));
        break;
      case 'Expires This Month':
        final nextMonth = now.add(const Duration(days: 30));
        final nextWeek = now.add(const Duration(days: 7));
        query = collection
            .where('expiryDate', isGreaterThan: Timestamp.fromDate(nextWeek))
            .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(nextMonth));
        break;
      case 'Valid':
        final nextMonth = now.add(const Duration(days: 30));
        query = collection.where('expiryDate', isGreaterThan: Timestamp.fromDate(nextMonth));
        break;
      default:
        query = collection.orderBy('expiryDate');
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  // Fetch products by category
  static Future<List<Product>> getProductsByCategory(String category) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final collection = getUserProductsCollection(userId);
    final snapshot = await collection.where('category', isEqualTo: category).get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }
}