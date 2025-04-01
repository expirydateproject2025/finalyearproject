import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Product {
  final String? id;  // Firebase document ID
  final String name;
  final String expiryDate;
  final String reminder;
  final int? quantity;
  final String? photoUrl;
  final String? category;
  final String? userId;  // Add user ID to associate products with users
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    required this.expiryDate,
    required this.reminder,
    this.quantity,
    this.photoUrl,
    this.category,
    this.userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) :
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    // Get current user ID if not provided
    String? currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;

    return {
      'name': name,
      'expiryDate': expiryDate,
      'reminder': reminder,
      'quantity': quantity,
      'photoUrl': photoUrl,
      'category': category,
      'userId': currentUserId,  // Include user ID in the map
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      expiryDate: map['expiryDate'] ?? '',
      reminder: map['reminder'] ?? '',
      quantity: map['quantity'],
      photoUrl: map['photoUrl'],
      category: map['category'],
      userId: map['userId'],  // Parse user ID from map
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? expiryDate,
    String? reminder,
    int? quantity,
    String? photoUrl,
    String? category,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      expiryDate: expiryDate ?? this.expiryDate,
      reminder: reminder ?? this.reminder,
      quantity: quantity ?? this.quantity,
      photoUrl: photoUrl ?? this.photoUrl,
      category: category ?? this.category,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to create a Product from a DocumentSnapshot
  static Product fromSnapshot(DocumentSnapshot snap) {
    return Product.fromMap(
      snap.id,
      snap.data() as Map<String, dynamic>,
    );
  }

  // Helper method to get collection reference
  static CollectionReference<Map<String, dynamic>> get collection {
    return FirebaseFirestore.instance.collection('products');
  }

  // CRUD Operations

  // Create
  Future<DocumentReference> save() async {
    // Ensure userId is set when saving
    Map<String, dynamic> data = toMap();
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
        .map((doc) => Product.fromSnapshot(doc))
        .toList();
  }

  // Read products expiring soon
  static Future<List<Product>> getExpiringSoon(int daysThreshold) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    // Calculate the date threshold
    DateTime now = DateTime.now();
    DateTime threshold = now.add(Duration(days: daysThreshold));
    String thresholdStr = "${threshold.year}-${threshold.month.toString().padLeft(2, '0')}-${threshold.day.toString().padLeft(2, '0')}";

    QuerySnapshot snapshot = await collection
        .where('userId', isEqualTo: userId)
        .where('expiryDate', isLessThanOrEqualTo: thresholdStr)
        .orderBy('expiryDate')
        .get();

    return snapshot.docs
        .map((doc) => Product.fromSnapshot(doc))
        .toList();
  }

  // Read
  static Future<Product?> getById(String id) async {
    final doc = await collection.doc(id).get();
    if (doc.exists) {
      return Product.fromSnapshot(doc);
    }
    return null;
  }

  // Update
  Future<void> update() async {
    if (id != null) {
      await collection.doc(id).update({
        ...toMap(),
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