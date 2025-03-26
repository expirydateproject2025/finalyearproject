import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductCard extends StatefulWidget {
  final String id;
  final String name;
  final DateTime expiryDate;
  final int? quantity;
  final String? photoPath;
  final String? category;
  final String? description;
  final Function(String) onEdit;
  final Function(String) onDelete;

  const ProductCard({
    Key? key,
    required this.id,
    required this.name,
    required this.expiryDate,
    this.quantity,
    this.photoPath,
    this.category,
    this.description,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  // Calculate days remaining until expiry
  int get daysRemaining {
    return widget.expiryDate.difference(DateTime.now()).inDays;
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
    return DateFormat('MMM dd, yyyy').format(widget.expiryDate);
  }

  // Enhanced product deletion with multiple database support
  void _deleteProduct(String id) async {
    try {
      // Delete from Firestore
      await FirebaseFirestore.instance.collection('products').doc(id).delete();

      // Optional: Delete from Realtime Database if used
      // final databaseRef = FirebaseDatabase.instance.ref().child('products').child(id);
      // await databaseRef.remove();

      widget.onDelete(id);

      // Show deletion confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$id deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Comprehensive edit dialog with more fields and validation
  Future<void> _showDetailedEditDialog(BuildContext context) async {
    final nameController = TextEditingController(text: widget.name);
    final quantityController = TextEditingController(text: widget.quantity?.toString() ?? '');
    final expiryController = TextEditingController(text: formattedDate);
    final descriptionController = TextEditingController(text: widget.description ?? '');
    String? selectedCategory = widget.category;

    final categories = [
      'Meat', 'Sweets', 'Juice', 'Dairy',
      'Patisserie', 'Grains', 'Medicine', 'Others'
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Product Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name TextField with validation
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: const Icon(Icons.shopping_basket),
                        errorText: nameController.text.isEmpty ? 'Name cannot be empty' : null,
                      ),
                      validator: (value) =>
                      value != null && value.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 10),

                    // Quantity TextField with validation
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: const Icon(Icons.numbers),
                        errorText: quantityController.text.isEmpty
                            ? 'Quantity is required'
                            : (int.tryParse(quantityController.text) == null
                            ? 'Invalid number'
                            : null),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Expiry Date Picker
                    TextFormField(
                      controller: expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: widget.expiryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            expiryController.text =
                                DateFormat('MMM dd, yyyy').format(pickedDate);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Description TextField
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      hint: const Text('Select Category'),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category),
                        labelText: 'Category',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Comprehensive Validation
                    if (nameController.text.isEmpty ||
                        quantityController.text.isEmpty ||
                        int.tryParse(quantityController.text) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields correctly'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Save updated product
                    _updateProduct(
                        nameController.text,
                        int.parse(quantityController.text),
                        DateTime.parse(expiryController.text),
                        descriptionController.text,
                        selectedCategory
                    );

                    Navigator.pop(context);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Update product in Firestore with comprehensive details
  void _updateProduct(
      String name,
      int quantity,
      DateTime expiryDate,
      String description,
      String? category
      ) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.id)
          .update({
        'name': name,
        'quantity': quantity,
        'expiryDate': expiryDate,
        'description': description,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onEdit(widget.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.id),
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
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm Deletion"),
              content: Text("Are you sure you want to delete ${widget.name}?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("CANCEL"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("DELETE"),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) => _deleteProduct(widget.id),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Enhanced UI
              GestureDetector(
                onTap: () {
                  // Optional: Show full image in a dialog
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: widget.photoPath != null
                          ? Image.file(File(widget.photoPath!))
                          : const Placeholder(),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: widget.photoPath != null
                        ? DecorationImage(
                      image: FileImage(File(widget.photoPath!)),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: widget.photoPath == null
                        ? Colors.grey.shade200
                        : null,
                  ),
                  child: widget.photoPath == null
                      ? const Icon(Icons.image, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Enhanced Details with Icons
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      text: 'Expires: $formattedDate',
                      color: expiryColor,
                    ),
                    _buildDetailRow(
                      icon: Icons.inventory_2,
                      text: 'Quantity: ${widget.quantity ?? 0}',
                      color: Colors.blue,
                    ),
                    _buildDetailRow(
                      icon: Icons.category,
                      text: 'Category: ${widget.category ?? "Uncategorized"}',
                      color: Colors.green,
                    ),
                    Text(
                      daysRemaining > 0
                          ? '$daysRemaining days remaining'
                          : 'Expired!',
                      style: TextStyle(
                        color: expiryColor,
                        fontWeight: daysRemaining <= 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit and More Options
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showDetailedEditDialog(context);
                      break;
                    case 'delete':
                      _deleteProduct(widget.id);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build consistent detail rows
  Widget _buildDetailRow({
    required IconData icon,
    required String text,
    required Color color
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}