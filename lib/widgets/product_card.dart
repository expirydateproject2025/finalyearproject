import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:cloudinary_public/cloudinary_public.dart';

class ProductCard extends StatefulWidget {
  final String id;
  final String name;
  final DateTime expiryDate;
  final int? quantity;
  final String? photoUrl; // Cloudinary URL
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
    this.photoUrl,
    this.category,
    this.description,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final cloudinary = CloudinaryPublic('dygaj4tbo', 'PRODUCT PHOTO');

  int get daysRemaining => widget.expiryDate.difference(DateTime.now()).inDays;

  Color get expiryColor {
    if (daysRemaining <= 0) return Colors.red;
    if (daysRemaining <= 7) return Colors.orange;
    if (daysRemaining <= 30) return Colors.yellow;
    return Colors.green;
  }

  String get formattedDate => DateFormat('MMM dd, yyyy').format(widget.expiryDate);

  Future<void> _deleteProduct(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(id)
          .delete();

      // Delete image from Cloudinary if exists
      Future<void> deleteImage(String publicId) async {
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final signature = generateSignature(publicId, timestamp); // You'll need to implement this

        final response = await http.post(
          Uri.parse('https://api.cloudinary.com/v1_1/dygaj4tbo/image/destroy'),
          body: {
            'public_id': publicId,
            'api_key': 'YOUR_API_KEY',
            'timestamp': timestamp.toString(),
            'signature': signature,
          },
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to delete image: ${response.body}');
        }
      }

      widget.onDelete(id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  String _extractPublicId(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');
    return segments.sublist(uploadIndex + 2).join('/').split('.')[0];
  }

  // Pick image from gallery or camera
  Future<File?> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedFile = await showDialog<XFile?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Image Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Gallery"),
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickImage(source: ImageSource.gallery),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickImage(source: ImageSource.camera),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // Upload image to Cloudinary
  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      final fileName = '${widget.id}_${DateTime.now().millisecondsSinceEpoch}';

      // Upload file
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'product_photos',
          publicId: fileName,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('Cloudinary upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      return null;
    }
  }

  // Show edit dialog
  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: widget.name);
    final quantityController = TextEditingController(text: widget.quantity?.toString() ?? '');
    final expiryController = TextEditingController(text: formattedDate);
    final descriptionController = TextEditingController(text: widget.description ?? '');
    String? selectedCategory = widget.category;
    String? currentPhotoUrl = widget.photoUrl;
    File? newImageFile;
    bool isUploading = false;

    final categories = [
      'Meat', 'Dairy', 'Fruits', 'Vegetables',
      'Grains', 'Sweets', 'Beverages', 'Others'
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image preview/upload
                    GestureDetector(
                      onTap: () async {
                        final pickedImage = await _pickImage();
                        if (pickedImage != null) {
                          setState(() {
                            newImageFile = pickedImage;
                          });
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade200,
                          image: newImageFile != null
                              ? DecorationImage(
                            image: FileImage(newImageFile!),
                            fit: BoxFit.cover,
                          )
                              : (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty
                              ? DecorationImage(
                            image: NetworkImage(currentPhotoUrl!),
                            fit: BoxFit.cover,
                          )
                              : null),
                        ),
                        child: (newImageFile == null &&
                            (currentPhotoUrl == null || currentPhotoUrl!.isEmpty))
                            ? const Icon(Icons.add_a_photo, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Name field
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.shopping_basket),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quantity field
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Expiry date field
                    TextFormField(
                      controller: expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: widget.expiryDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

                    // Description field
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category dropdown
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
                if (isUploading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () async {
                      // Validate inputs
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

                      setState(() {
                        isUploading = true;
                      });

                      // Upload new image if selected
                      String? photoUrl = currentPhotoUrl;
                      if (newImageFile != null) {
                        photoUrl = await _uploadToCloudinary(newImageFile!);
                      }

                      // Parse date
                      DateTime expiryDate;
                      try {
                        expiryDate = DateFormat('MMM dd, yyyy').parse(expiryController.text);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid date format'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setState(() {
                          isUploading = false;
                        });
                        return;
                      }

                      // Update product
                      await _updateProduct(
                        nameController.text,
                        int.parse(quantityController.text),
                        expiryDate,
                        descriptionController.text,
                        selectedCategory,
                        photoUrl,
                      );

                      setState(() {
                        isUploading = false;
                      });

                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // Update product in Firestore
  Future<void> _updateProduct(
      String name,
      int quantity,
      DateTime expiryDate,
      String description,
      String? category,
      String? photoUrl,
      ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Create data map
      final data = {
        'name': name,
        'quantity': quantity,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'description': description,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add photo URL if it exists
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(widget.id)
          .update(data);

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
              // Product Image
              GestureDetector(
                onTap: () {
                  if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: Image.network(
                          widget.photoUrl!,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            );
                          },
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(widget.photoUrl!),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: widget.photoUrl == null || widget.photoUrl!.isEmpty
                        ? Colors.grey.shade200
                        : null,
                  ),
                  child: widget.photoUrl == null || widget.photoUrl!.isEmpty
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

              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditDialog();
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

  // Helper method for detail rows
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