import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductEditScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductEditScreen({Key? key, this.product}) : super(key: key);

  @override
  _ProductEditScreenState createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _descriptionController;
  late TextEditingController _expiryController;

  String? _selectedCategory;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Meat', 'Sweets', 'Juice', 'Dairy',
    'Patisserie', 'Grains', 'Medicine', 'Others'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.product?['name'] ?? '');
    _quantityController = TextEditingController(
        text: widget.product?['quantity']?.toString() ?? ''
    );
    _descriptionController = TextEditingController(
        text: widget.product?['description'] ?? ''
    );
    _expiryController = TextEditingController(
        text: widget.product?['expiryDate'] != null
            ? DateFormat('MMM dd, yyyy').format(widget.product?['expiryDate'].toDate())
            : ''
    );
    _selectedCategory = widget.product?['category'];

    // If existing product has a photo path, load it
    if (widget.product?['photoPath'] != null) {
      _imageFile = File(widget.product?['photoPath']);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final productData = {
        'name': _nameController.text,
        'quantity': int.parse(_quantityController.text),
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'expiryDate': Timestamp.fromDate(
            DateFormat('MMM dd, yyyy').parse(_expiryController.text)
        ),
        'photoPath': _imageFile?.path,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.product == null) {
        // New product
        await FirebaseFirestore.instance.collection('products').add(productData);
      } else {
        // Update existing product
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!['id'])
            .update(productData);
      }

      Navigator.pop(context, true); // Return success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null
            ? 'Add New Product'
            : 'Edit Product'
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    image: _imageFile != null
                        ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                      Text('Tap to add product image'),
                    ],
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  prefixIcon: Icon(Icons.shopping_basket),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.isEmpty
                    ? 'Please enter product name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Expiry Date
              TextFormField(
                controller: _expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    _expiryController.text =
                        DateFormat('MMM dd, yyyy').format(pickedDate);
                  }
                },
                validator: (value) =>
                value == null || value.isEmpty
                    ? 'Please select expiry date'
                    : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select Category'),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) =>
                value == null
                    ? 'Please select a category'
                    : null,
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                    widget.product == null
                        ? 'Add Product'
                        : 'Update Product'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _expiryController.dispose();
    super.dispose();
  }
}