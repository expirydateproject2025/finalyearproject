import 'package:flutter/material.dart';
import 'dart:io';
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
  // Initialize Cloudinary client
  // Replace with your actual Cloudinary credentials
  final cloudinary = CloudinaryPublic('dygaj4tbo', 'PRODUCT PHOTO', cache: true);

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

  // Delete product and its image from Cloudinary
  void _deleteProduct(String id) async {
    try {
      // Get the product data to get the photo URL before deletion
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(id).get();
      final data = productDoc.data();
      final photoUrl = data?['photoUrl'] as String?;

      // Delete from Cloudinary if URL exists and contains Cloudinary URL pattern
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.contains('cloudinary.com')) {
        try {
          // Extract the public ID from the URL
          // Typically, Cloudinary URLs are like: https://res.cloudinary.com/YOUR_CLOUD_NAME/image/upload/v123456789/public_id.jpg
          final Uri uri = Uri.parse(photoUrl);
          final pathSegments = uri.pathSegments;

          // Get the filename without extension which is typically the last part of the URL
          if (pathSegments.length > 2) {
            // The public ID is typically the last segment without file extension
            final String publicId = path.basenameWithoutExtension(pathSegments.last);

            // You would need server-side code to delete from Cloudinary
            // as client-side deletion requires API Secret which shouldn't be exposed
            // Here we're just showing how you might handle the logic
            print('Would delete image with publicId: $publicId from Cloudinary');

            // In production, you might have a Cloud Function or a backend API for this:
            // await deleteCloudinaryImage(publicId);
          }
        } catch (e) {
          print('Failed to parse/delete Cloudinary image: $e');
          // Continue with product deletion even if photo deletion fails
        }
      }

      // Delete from Firestore
      await FirebaseFirestore.instance.collection('products').doc(id).delete();

      widget.onDelete(id);

      // Show deletion confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product deleted successfully'),
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

      // Upload file without transformations
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'PRODUCT_PHOTOS',
          publicId: fileName,
        ),
      );

      // Apply transformations by modifying the URL
      String imageUrl = response.secureUrl;
      final Uri uri = Uri.parse(imageUrl);
      final String path = uri.path;
      final int uploadIndex = path.indexOf('/upload/');

      if (uploadIndex != -1) {
        // Insert transformations after '/upload/'
        final String newPath = path.substring(0, uploadIndex + 8) +
            'w_800,h_600,c_limit,q_auto,f_auto/' +
            path.substring(uploadIndex + 8);
        imageUrl = uri.replace(path: newPath).toString();
      }

      return imageUrl;
    } catch (e) {
      print('Cloudinary upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      return null;
    }
  }

  // Comprehensive edit dialog with more fields, validation, and photo upload
  Future<void> _showDetailedEditDialog(BuildContext context) async {
    final nameController = TextEditingController(text: widget.name);
    final quantityController = TextEditingController(text: widget.quantity?.toString() ?? '');
    final expiryController = TextEditingController(text: formattedDate);
    final descriptionController = TextEditingController(text: widget.description ?? '');
    String? selectedCategory = widget.category;
    String? currentPhotoUrl = widget.photoUrl;
    File? newImageFile;
    bool isUploading = false;

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
                    // Product Image Preview and Upload
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
                    const SizedBox(height: 5),
                    Text(
                      'Tap to change image',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),

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
                      readOnly: true, // Prevent keyboard from showing
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: widget.expiryDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past dates for expired products
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
                if (isUploading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () async {
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

                      setState(() {
                        isUploading = true;
                      });

                      // Upload new image to Cloudinary if selected
                      String? photoUrl = currentPhotoUrl;
                      if (newImageFile != null) {
                        photoUrl = await _uploadToCloudinary(newImageFile!);
                      }

                      // Parse the date from the controller
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

                      // Save updated product
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
                    child: const Text('Save Changes'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // Update product in Firestore with comprehensive details including photo
  Future<void> _updateProduct(
      String name,
      int quantity,
      DateTime expiryDate,
      String description,
      String? category,
      String? photoUrl,
      ) async {
    try {
      // Create data map with all fields
      final data = {
        'name': name,
        'quantity': quantity,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'description': description,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only add photoUrl if it exists
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }

      // Update Firestore
      await FirebaseFirestore.instance
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
              // Product Image with Enhanced UI - Now supports Cloudinary images
              GestureDetector(
                onTap: () {
                  // Show full image in a dialog with Cloudinary transformations for optimized viewing
                  if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
                    // Modify URL to get optimized image if it's a Cloudinary URL
                    String displayUrl = widget.photoUrl!;
                    if (displayUrl.contains('cloudinary.com')) {
                      // Add transformations for full-screen view - e.g., quality auto, format auto
                      // This assumes standard Cloudinary URL structure
                      final Uri uri = Uri.parse(displayUrl);
                      final String path = uri.path;
                      final int uploadIndex = path.indexOf('/upload/');

                      if (uploadIndex != -1) {
                        // Insert transformations after '/upload/'
                        final String newPath = path.substring(0, uploadIndex + 8) +
                            'q_auto,f_auto/' +
                            path.substring(uploadIndex + 8);
                        displayUrl = uri.replace(path: newPath).toString();
                      }
                    }

                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: Image.network(
                          displayUrl,
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
                            return Center(
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
                      // For thumbnails, we can optimize with Cloudinary transformations
                      image: NetworkImage(_getOptimizedThumbnailUrl(widget.photoUrl!)),
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

  // Helper method to get optimized thumbnail URL from Cloudinary
  String _getOptimizedThumbnailUrl(String url) {
    // If it's a Cloudinary URL, add transformations for thumbnail
    if (url.contains('cloudinary.com')) {
      final Uri uri = Uri.parse(url);
      final String path = uri.path;
      final int uploadIndex = path.indexOf('/upload/');

      if (uploadIndex != -1) {
        // Insert transformations after '/upload/'
        // w_160,h_160,c_fill = width 160px, height 160px, crop mode fill
        // q_auto = automatic quality optimization
        // f_auto = automatic format selection (WebP for supported browsers)
        final String newPath = path.substring(0, uploadIndex + 8) +
            'w_160,h_160,c_fill,q_auto,f_auto/' +
            path.substring(uploadIndex + 8);
        return uri.replace(path: newPath).toString();
      }
    }
    return url;
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