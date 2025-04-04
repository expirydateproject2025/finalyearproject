import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:expirydatetracker/widgets/custom_product_text_field.dart';
import 'package:expirydatetracker/widgets/product_categories.dart';
import 'package:expirydatetracker/utils/date_utils.dart';
import 'package:intl/intl.dart';
import 'package:expirydatetracker/models/product_model.dart';
import 'package:expirydatetracker/widgets/bottom_nav.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  // Create Cloudinary instance - replace with your own cloud name and upload preset
  final cloudinary = CloudinaryPublic('dygaj4tbo', 'PRODUCT PHOTO', cache: false);

  DateTime? _selectedDate;
  String _selectedReminder = '1 week';
  File? _productImage;
  String? _productImageUrl; // Store Cloudinary URL
  bool _isAutoMode = true;
  String? _selectedCategory;
  bool _isUploading = false; // Track image upload status
  bool _isSaving = false; // Track product saving status

  // Current index for bottom navigation
  int _currentIndex = 1; // Set to 1 since we're on the Add Product page

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();

    // Verify authentication
    _checkAuthentication();
  }

  // Check if user is authenticated
  void _checkAuthentication() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add products')),
        );
        Navigator.pushReplacementNamed(context, '/login'); // Redirect to login page
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickProductImage() async {
    if (_isUploading) return; // Prevent multiple uploads

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Choose Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context,
                        await picker.pickImage(source: ImageSource.camera));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context,
                        await picker.pickImage(source: ImageSource.gallery));
                  },
                ),
              ],
            ),
          );
        },
      );

      if (image != null) {
        setState(() {
          _productImage = File(image.path);
        });

        // Upload to Cloudinary when image is selected
        await _uploadImageToCloudinary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  // Upload image to Cloudinary with compression
  Future<void> _uploadImageToCloudinary() async {
    if (_productImage == null) return;

    try {
      setState(() {
        _isUploading = true;
      });

      // Compress the image before uploading
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _productImage!.path,
        quality: 70, // Adjust quality as needed (0-100)
      );

      if (compressedImage == null) {
        throw Exception("Failed to compress image");
      }

      // Get a unique filename using timestamp and user ID
      final user = FirebaseAuth.instance.currentUser;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'product_${user?.uid}_$timestamp';

      // Create a CloudinaryResponse by uploading the file
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _productImage!.path,
          folder: 'expiry_products',
          resourceType: CloudinaryResourceType.Image,
          publicId: fileName, // Use the unique filename
        ),
      );

      // Store the secure URL
      setState(() {
        _productImageUrl = response.secureUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      print('Cloudinary Upload Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  Future<void> _scanProduct() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

        if (mounted) {
          Navigator.pop(context);
        }

        String text = recognizedText.text;
        _processScannedText(text);

        textRecognizer.close();

        // Optionally save the scanned image as product image
        setState(() {
          _productImage = File(image.path);
        });

        // Upload the scanned image to Cloudinary
        await _uploadImageToCloudinary();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      print('Scan Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning product: $e')),
        );
      }
    }
  }

  void _processScannedText(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      // If name is empty and line doesn't look like a date => use as product name
      if (_nameController.text.isEmpty && !line.contains('/')) {
        _nameController.text = line.trim();
      }
      // If expiry is empty and line looks like a date => use as expiry
      if (_expiryController.text.isEmpty &&
          CustomDateUtils.isValidDateFormat(line)) {
        _expiryController.text = line.trim();
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _expiryController.text = _formatDate(_selectedDate!);
      });
    }
  }

  String _formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(date);
  }

  Widget _buildReminderChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedReminder == label,
      onSelected: (selected) {
        setState(() {
          _selectedReminder = label;
        });
      },
      selectedColor: Colors.deepOrange.withOpacity(0.8),
      backgroundColor: Colors.transparent,
    );
  }

  bool _validateForm() {
    // Check required fields
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product name')),
      );
      return false;
    }

    if (_expiryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date')),
      );
      return false;
    }

    // Validate expiry date format
    DateTime? expiryDate;
    try {
      expiryDate = DateFormat('yyyy-MM-dd').parse(_expiryController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format. Use YYYY-MM-DD')),
      );
      return false;
    }

    // Validate category is selected
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return false;
    }

    // Check if image is uploading
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, image is still uploading')),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveProduct() async {
    // Check if already saving
    if (_isSaving) return;

    // Validate form fields
    if (!_validateForm()) return;

    // Convert string date to DateTime
    DateTime expiryDate = DateFormat('yyyy-MM-dd').parse(_expiryController.text);

    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add products')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Show loading indicator
    setState(() {
      _isSaving = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Create the product object
      final product = Product(
        name: _nameController.text,
        expiryDate: expiryDate,
        category: _selectedCategory ?? 'Other',
        reminder: _selectedReminder,
        quantity: _quantityController.text.isNotEmpty
            ? int.parse(_quantityController.text)
            : 1,
        photoUrl: _productImageUrl, // This should be the Cloudinary URL
        userId: user.uid,
      );

      // Debug print
      print('Saving product: ${product.toFirestore()}');

      // Save to Firebase
      final docRef = await product.save();
      print('Product saved with ID: ${docRef.id}');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (error) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isSaving = false;
      });

      print('Detailed save error: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: $error')),
        );
      }
    }
  }

  // Handle navigation taps
  void _onNavigationTap(int index) {
    if (index != 1) { // If not the Add page
      Navigator.pushReplacementNamed(
        context,
        index == 0 ? '/home' : '/profile',
      );
    }
  }

  // Improved image section with better loading indicator
  Widget _buildImageSection() {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isUploading ? null : _pickProductImage, // Disable when uploading
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isUploading ? Colors.grey : Colors.deepOrange,
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_productImage != null)
                      ClipOval(
                        child: Image.file(
                          _productImage!,
                          fit: BoxFit.cover,
                          width: 150,
                          height: 150,
                        ),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.deepOrange,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Product Photo',
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    if (_isUploading)
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_productImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[200], size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Image uploaded to cloud',
                      style: TextStyle(
                        color: Colors.green[200],
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Product',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFDA4E00),
                Color(0xFFFFD834),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF070625),
                Color(0xFF120D9C),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode Selection
                Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Select Mode',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Auto'),
                              icon: Icon(Icons.auto_awesome),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Manual'),
                              icon: Icon(Icons.edit),
                            ),
                          ],
                          selected: {_isAutoMode},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              _isAutoMode = newSelection.first;
                            });
                          },
                          style: ButtonStyle(
                            backgroundColor:
                            MaterialStateProperty.resolveWith<Color>(
                                  (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.deepOrange;
                                }
                                return Colors.grey.shade200;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Product Image with improved UI
                _buildImageSection(),
                const SizedBox(height: 16),

                // Scan Button (Only visible in Auto mode)
                if (_isAutoMode)
                  Card(
                    color: Colors.transparent,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Scan Product Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFDA4E00),
                                  Color(0xFFFFD834),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _scanProduct,
                              icon: const Icon(Icons.qr_code_scanner,
                                  color: Colors.white),
                              label: const Text(
                                'Scan Product',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 60,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Rest of the form remains the same
                // Product Details Form
                Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomProductTextField(
                          controller: _nameController,
                          labelText: 'Product Name',
                          prefixIcon: Icons.shopping_basket,
                        ),
                        const SizedBox(height: 16),
                        CustomProductTextField(
                          controller: _quantityController,
                          labelText: 'Quantity (Optional)',
                          prefixIcon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: CustomProductTextField(
                              controller: _expiryController,
                              labelText: 'Expiry Date',
                              prefixIcon: Icons.calendar_today,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Categories
                Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StyledCategoryDropdown(
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (category) {
                        setState(() {
                          _selectedCategory =
                          category.isEmpty ? null : category;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reminder Selection
                Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reminder Before',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.deepOrange,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildReminderChip('1 day'),
                            _buildReminderChip('1 week'),
                            _buildReminderChip('1 month'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFDA4E00),
                        Color(0xFFFFD834),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Save Product',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      // Add the bottom navigation bar
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
}