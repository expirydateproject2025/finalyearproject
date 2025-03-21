import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;  // Firebase document ID
  final String name;
  final String expiryDate;
  final String reminder;
  final int? quantity;
  final String? photoUrl;
  final String? category;
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) :
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expiryDate': expiryDate,
      'reminder': reminder,
      'quantity': quantity,
      'photoUrl': photoUrl,
      'category': category,
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
    return await collection.add(toMap());
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