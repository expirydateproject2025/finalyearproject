import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:expirydatetracker/widgets/custom_product_text_field.dart';
import 'package:expirydatetracker/widgets/product_categories.dart';
import 'package:expirydatetracker/utils/date_utils.dart';
import 'package:intl/intl.dart';
import 'package:expirydatetracker/models/product_model.dart';
import 'package:expirydatetracker/widgets/animated_bottom_nav.dart';
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
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Use highest quality for OCR
      );

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
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

        if (mounted) {
          Navigator.pop(context);
        }

        // Focus specifically on expiry date extraction
        final DateTime? extractedDate = _extractExpiryDate(recognizedText.text);

        if (extractedDate != null) {
          setState(() {
            _selectedDate = extractedDate;
            _expiryController.text = _formatDate(extractedDate);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expiry date detected successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No expiry date detected. Please enter manually.')),
            );
          }
        }

        textRecognizer.close();

        // Save the scanned image as product image
        setState(() {
          _productImage = File(image.path);
        });

        // Upload the scanned image to Cloudinary
        await _uploadImageToCloudinary();
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

  // Method to extract expiry date from OCR text
  DateTime? _extractExpiryDate(String text) {
    // Common expiry date patterns and their prefixes
    final List<RegExp> datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})'),
      // MM/DD/YYYY or MM-DD-YYYY
      RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})'),
      // YYYY/MM/DD or YYYY-MM-DD
      RegExp(r'(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})'),
      // Common text prefixes with dates
      RegExp(r'(?:EXP|Exp|exp|Expiry|EXPIRY|Best Before|USE BY|Use by)[:\s]*(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})', caseSensitive: false),
      RegExp(r'(?:EXP|Exp|exp|Expiry|EXPIRY|Best Before|USE BY|Use by)[:\s]*(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})', caseSensitive: false),
    ];

    // Common expiry prefixes to look for in the text
    final List<String> expiryPrefixes = [
      'EXP', 'Exp', 'exp', 'Expiry', 'EXPIRY',
      'Best Before', 'best before', 'BEST BEFORE',
      'Use By', 'USE BY', 'use by',
      'BB', 'bb', 'Best By', 'best by'
    ];

    // Split text into lines for better processing
    final List<String> lines = text.split('\n');

    // First pass: Look for lines with expiry prefixes
    for (String line in lines) {
      // Check if line contains any of the expiry prefixes
      for (String prefix in expiryPrefixes) {
        if (line.contains(prefix)) {
          // This line likely contains expiry information, prioritize it
          DateTime? date = _tryParseDate(line, datePatterns);
          if (date != null) return date;
        }
      }
    }

    // Second pass: Scan all lines for date patterns
    for (String line in lines) {
      DateTime? date = _tryParseDate(line, datePatterns);
      if (date != null) {
        // Validate date is in the future (likely an expiry date)
        if (date.isAfter(DateTime.now())) {
          return date;
        }
      }
    }

    return null;
  }

  // Helper method to try parsing a date from text using multiple patterns
  DateTime? _tryParseDate(String text, List<RegExp> patterns) {
    for (RegExp pattern in patterns) {
      final matches = pattern.allMatches(text);

      for (final match in matches) {
        try {
          if (match.groupCount >= 3) {
            int? day, month, year;

            // Pattern: DD/MM/YYYY
            if (int.parse(match.group(1)!) <= 31 && int.parse(match.group(2)!) <= 12) {
              day = int.parse(match.group(1)!);
              month = int.parse(match.group(2)!);
              year = int.parse(match.group(3)!);

              // Handle 2-digit years
              if (year! < 100) {
                year += 2000; // Assuming 21st century
              }
            }
            // Pattern: MM/DD/YYYY
            else if (int.parse(match.group(1)!) <= 12 && int.parse(match.group(2)!) <= 31) {
              month = int.parse(match.group(1)!);
              day = int.parse(match.group(2)!);
              year = int.parse(match.group(3)!);

              if (year! < 100) {
                year += 2000;
              }
            }
            // Pattern: YYYY/MM/DD
            else if (match.group(1)!.length == 4) {
              year = int.parse(match.group(1)!);
              month = int.parse(match.group(2)!);
              day = int.parse(match.group(3)!);
            }

            if (day != null && month != null && year != null) {
              // Validate ranges
              if (day > 0 && day <= 31 && month > 0 && month <= 12 && year >= 2000) {
                return DateTime(year, month, day);
              }
            }
          }
        } catch (e) {
          print('Date parsing error: $e');
          // Continue to next match if this one fails
        }
      }
    }

    return null;
  }

  // Process the scanned text to extract product name and expiry date
  void _processScannedText(String text) {
    // Extract product name using heuristics (avoid date-like patterns)
    final lines = text.split('\n');

    bool nameFound = false;
    bool dateFound = false;

    // Try to find date first
    DateTime? expiryDate = _extractExpiryDate(text);
    if (expiryDate != null) {
      _expiryController.text = _formatDate(expiryDate);
      _selectedDate = expiryDate;
      dateFound = true;
    }

    // Find potential product name (prioritize longer lines that aren't dates)
    for (String line in lines) {
      // Skip empty lines or very short text
      if (line.trim().length < 3) continue;

      // Skip lines that look like dates
      if (CustomDateUtils.isValidDateFormat(line)) continue;

      // Skip lines with common expiry-related words
      if (line.contains('EXP') ||
          line.toLowerCase().contains('expiry') ||
          line.toLowerCase().contains('best before') ||
          line.toLowerCase().contains('use by')) {
        continue;
      }

      // Use this line as product name
      if (_nameController.text.isEmpty && !nameFound) {
        _nameController.text = line.trim();
        nameFound = true;
        break;
      }
    }

    // If we didn't find a date through the extractor but there's a line that looks like a date
    if (!dateFound && _expiryController.text.isEmpty) {
      for (String line in lines) {
        if (CustomDateUtils.isValidDateFormat(line)) {
          _expiryController.text = line.trim();
          break;
        }
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
      final int quantity;
      try {
        quantity = _quantityController.text.isNotEmpty
            ? int.parse(_quantityController.text)
            : 1;
      } catch (e) {
        throw Exception('Invalid quantity format: ${_quantityController.text}');
      }

      final product = Product(
        name: _nameController.text,
        expiryDate: expiryDate,
        category: _selectedCategory ?? 'Other',
        reminder: _selectedReminder,
        quantity: quantity,
        photoUrl: _productImageUrl,
        userId: user.uid,
      );


      // Debug print product data
      print('About to save product with data: ${product.toFirestore()}');

      // Verify Firestore structure
      print('Saving to collection: users/${user.uid}/products');

      // Save the product
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

      print('DETAILED SAVE ERROR: $error');
      print('Error type: ${error.runtimeType}');
      if (error is FirebaseException) {
        print('Firebase error code: ${error.code}');
        print('Firebase error message: ${error.message}');
      }

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

    );
  }
}