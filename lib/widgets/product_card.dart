import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final DateTime expiryDate;
  final int? quantity; // Nullable
  final String? photoPath;
  final Function(String) onEdit;
  final Function(String) onDelete;

  const ProductCard({
    Key? key,
    required this.id,
    required this.name,
    required this.expiryDate,
    this.quantity,
    this.photoPath,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  // Calculate days remaining until expiry
  int get daysRemaining {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  // Determine color based on days remaining
  Color get expiryColor {
    if (daysRemaining <= 0) {
      return Colors.red;
    } else if (daysRemaining <= 7) {
      return Colors.orange;
    } else if (daysRemaining <= 30) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  // Format date as readable string
  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(expiryDate);
  }

  // Delete product from Firebase Realtime Database
  void _deleteProduct(String id) async {
    final databaseRef = FirebaseDatabase.instance.ref().child('products').child(id);
    await databaseRef.remove();
    onDelete(id); // Call the onDelete callback
  }

  // Edit product in Firebase Realtime Database
  void _editProduct(BuildContext context, String id) async {
    // Navigate to an edit screen or show a dialog to update the product
    // For simplicity, let's assume we update the name and quantity
    final newName = await _showEditDialog(context, name, quantity ?? 0);
    if (newName != null) {
      final databaseRef = FirebaseDatabase.instance.ref().child('products').child(id);
      await databaseRef.update({
        'name': newName,
        'quantity': quantity,
      });
      onEdit(id); // Call the onEdit callback
    }
  }

  // Show an edit dialog
  Future<String?> _showEditDialog(BuildContext context, String currentName, int currentQuantity) async {
    final nameController = TextEditingController(text: currentName);
    final quantityController = TextEditingController(text: currentQuantity.toString());

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newQuantity = int.tryParse(quantityController.text.trim()) ?? 0;
                if (newName.isNotEmpty && newQuantity > 0) {
                  Navigator.pop(context, newName);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteProduct(id); // Call delete function
      },
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm"),
              content: const Text("Are you sure you want to delete this item?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("CANCEL"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("DELETE"),
                ),
              ],
            );
          },
        );
      },
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: photoPath != null
                      ? Image.file(
                    File(photoPath!),
                    fit: BoxFit.cover,
                  )
                      : const Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis, // Prevent text overflow
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: expiryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Expires: $formattedDate',
                            style: TextStyle(
                              color: expiryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis, // Prevent text overflow
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Quantity: ${quantity ?? 0}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis, // Prevent text overflow
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysRemaining > 0
                          ? '$daysRemaining days remaining'
                          : 'Expired!',
                      style: TextStyle(
                        color: expiryColor,
                        fontWeight: daysRemaining <= 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis, // Prevent text overflow
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editProduct(context, id), // Pass context here
              ),
            ],
          ),
        ),
      ),
    );
  }
}