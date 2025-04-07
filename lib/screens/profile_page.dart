import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:expirydatetracker/models/product_model.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:expirydatetracker/models//ProductProvider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  File? _profileImage;
  String? _profileImageUrl;
  String _currentView = 'stats'; // 'stats', 'total', 'expiring', 'monthly'

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          setState(() {
            _nameController.text = userDoc['name'] ?? '';
            _emailController.text = user.email ?? '';
            _profileImageUrl = userDoc['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _profileImage = File(image.path));
        await _uploadProfileImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('profile_images/${user.uid}');
      await ref.putFile(_profileImage!);
      _profileImageUrl = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).set({
        'profileImageUrl': _profileImageUrl,
      }, SetOptions(merge: true));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': _nameController.text,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  // Statistics methods (would connect to your products collection)
  int _getTotalItems(BuildContext context) {
    return Provider.of<ProductProvider>(context, listen: false).totalItems;
  }

  int _getExpiringSoon(BuildContext context) {
    return Provider.of<ProductProvider>(context, listen: false).expiringSoon;
  }

  int _getTrackedThisMonth(BuildContext context) {
    return Provider.of<ProductProvider>(context, listen: false).trackedThisMonth;
  }

  Widget _buildStatsView() {
    // Use Consumer for reactive UI updates
    return Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          return Column(
            children: [
              _buildStatCard('Total Items Tracked', productProvider.totalItems, Icons.inventory),
              _buildStatCard('Items Expiring Soon', productProvider.expiringSoon, Icons.warning),
              _buildStatCard('Items Tracked This Month', productProvider.trackedThisMonth, Icons.calendar_today),
            ],
          );
        }
    );
  }

  Widget _buildDetailView() {
    return Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          List<Product> items = [];

          if (_currentView == 'total') {
            items = productProvider.products;
          } else if (_currentView == 'expiring') {
            items = productProvider.productsExpiringThisWeek;
          } else if (_currentView == 'monthly') {
            final now = DateTime.now();
            final firstDayOfMonth = DateTime(now.year, now.month, 1);
            items = productProvider.products
                .where((p) => p.createdAt.isAfter(firstDayOfMonth))
                .toList();
          }

          return ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final product = items[index];
              return ListTile(
                title: Text(
                    product.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  // Format the date using DateFormat from intl package
                  'Expires: ${DateFormat('MMM dd, yyyy').format(
                      product.expiryDate)}',
                  style: TextStyle(
                    color: product.isExpired ? Colors.red : Colors.white70,
                  ),
                ),
                leading: Icon(
                  product.isExpired ? Icons.warning : Icons.check_circle,
                  color: product.isExpired ? Colors.red : Colors.green,
                ),
              );
            },
          );
        }
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            fontFamily: 'Poppins',
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDA4E00), Color(0xFFFFD834)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070625), Color(0xFF120D9C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!) as ImageProvider
                              : _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : const AssetImage('assets/default_profile.png') as ImageProvider,
                        ),
                      ),
                      if (_isEditing)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD834),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildEditableField(_nameController, 'Name', true),
                const SizedBox(height: 16),
                _buildEditableField(_emailController, 'Email', false),
                const SizedBox(height: 24),
                if (_currentView == 'stats') _buildStatsView(),
                if (_currentView != 'stats') ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _currentView = 'stats'),
                  ),
                  _buildDetailView(),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDA4E00),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, size: 28, color: const Color(0xFFFFD834)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: Text(count.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 20)),
        onTap: () {
          setState(() {
            if (title == 'Total Items Tracked') _currentView = 'total';
            if (title == 'Items Expiring Soon') _currentView = 'expiring';
            if (title == 'Items Tracked This Month') _currentView = 'monthly';
          });
        },
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller, String label, bool editable) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFFD834)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              enabled: _isEditing && editable,
              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
            ),
          ),
          if (_isEditing && editable)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFFFFD834)),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}