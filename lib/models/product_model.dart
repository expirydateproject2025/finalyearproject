import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Product {
  final String? id;
  final String name;
  final DateTime expiryDate;
  final String category; // Changed to non-nullable
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
    required this.category, // Now required
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
      'quantity': quantity,
      'photoUrl': photoUrl,
      'barcode': barcode,
      'notes': notes,
      'userId': currentUserId,
      'notificationsScheduled': notificationsScheduled,
      'scheduledNotifications': scheduledNotifications,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      category: data['category'] ?? '',
      reminder: data['reminder'],
      quantity: data['quantity'],
      photoUrl: data['photoUrl'],
      barcode: data['barcode'],
      notes: data['notes'],
      userId: data['userId'],
      notificationsScheduled: data['notificationsScheduled'] ?? false,
      scheduledNotifications: data['scheduledNotifications'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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
      updatedAt: updatedAt ?? this.updatedAt,
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

  // Collection reference
  static CollectionReference<Map<String, dynamic>> get collection {
    return FirebaseFirestore.instance.collection('products');
  }

  // CRUD Operations

  // Create
  Future<DocumentReference> save() async {
    Map<String, dynamic> data = toFirestore();
    if (data['userId'] == null) {
      data['userId'] = FirebaseAuth.instance.currentUser?.uid;
    }
    return await collection.add(data);
  }

  // Read all products for current user
  static Future<List<Product>> getAllForCurrentUser() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    QuerySnapshot snapshot = await collection
        .where('userId', isEqualTo: userId)
        .orderBy('expiryDate')
        .get();

    return snapshot.docs
        .map((doc) => Product.fromFirestore(doc))
        .toList();
  }

  // Read products expiring soon
  static Future<List<Product>> getExpiringSoon(int daysThreshold) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    DateTime now = DateTime.now();
    DateTime threshold = now.add(Duration(days: daysThreshold));

    QuerySnapshot snapshot = await collection
        .where('userId', isEqualTo: userId)
        .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(threshold))
        .orderBy('expiryDate')
        .get();

    return snapshot.docs
        .map((doc) => Product.fromFirestore(doc))
        .toList();
  }

  // Read single product
  static Future<Product?> getById(String id) async {
    final doc = await collection.doc(id).get();
    if (doc.exists) {
      return Product.fromFirestore(doc);
    }
    return null;
  }

  // Update
  Future<void> update() async {
    if (id != null) {
      await collection.doc(id).update({
        ...toFirestore(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  // Delete
  Future<void> delete() async {
    if (id != null) {
      await collection.doc(id).delete();
    }
  }
}