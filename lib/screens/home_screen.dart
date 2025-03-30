import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expirydatetracker/widgets/bottom_nav.dart';
import 'package:expirydatetracker/screens/notification_page.dart';
import 'package:expirydatetracker/screens/profile_page.dart';
import 'package:expirydatetracker/widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0 => Home, 1 => Add, 2 => Profile
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedSort = 'Expiry Date (Low to High)';

  final List<String> _sortOptions = [
    'Expiry Date (Low to High)',
    'Expiry Date (High to Low)',
    'Name (A to Z)',
    'Name (Z to A)',
    'Expired First',
    'Recently Added',
  ];

  final List<String> _filterOptions = ['All', 'Food', 'Medicine'];

  // Helper function to parse dates from Firestore
  DateTime _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is String) {
      return DateTime.parse(date);
    }
    throw Exception('Invalid date format');
  }

  // Filter and sort products based on user selections
  List<Map<String, dynamic>> _getFilteredAndSortedProducts(List<Map<String, dynamic>> products) {
    // Filter products
    var filteredProducts = products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product['description'] != null &&
              product['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesFilter = _selectedFilter == 'All' ||
          product['category'].toString() == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    // Sort products
    switch (_selectedSort) {
      case 'Expiry Date (Low to High)':
        filteredProducts.sort((a, b) => (a['expiryDate'] as DateTime).compareTo(b['expiryDate'] as DateTime));
        break;
      case 'Expiry Date (High to Low)':
        filteredProducts.sort((a, b) => (b['expiryDate'] as DateTime).compareTo(a['expiryDate'] as DateTime));
        break;
      case 'Name (A to Z)':
        filteredProducts.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
        break;
      case 'Name (Z to A)':
        filteredProducts.sort((a, b) => b['name'].toString().toLowerCase().compareTo(a['name'].toString().toLowerCase()));
        break;
      case 'Expired First':
        final now = DateTime.now();
        filteredProducts.sort((a, b) {
          final aExpired = (a['expiryDate'] as DateTime).isBefore(now);
          final bExpired = (b['expiryDate'] as DateTime).isBefore(now);
          if (aExpired != bExpired) return aExpired ? -1 : 1;
          return (a['expiryDate'] as DateTime).compareTo(b['expiryDate'] as DateTime);
        });
        break;
      case 'Recently Added':
        filteredProducts.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
        break;
    }

    return filteredProducts;
  }

  // Build the search bar
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.search, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  // Build the sort dropdown
  Widget _buildSortDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSort,
          isExpanded: true,
          dropdownColor: const Color(0xFF082969),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.sort, color: Colors.white),
          items: _sortOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedSort = newValue);
            }
          },
        ),
      ),
    );
  }

  // Build filter chips
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: _filterOptions.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _selectedFilter == filter,
              label: Text(filter),
              onSelected: (bool selected) {
                setState(() => _selectedFilter = filter);
              },
              selectedColor: const Color(0xFFFB6E1E).withOpacity(0.2),
              checkmarkColor: const Color(0xFFFB6E1E),
              labelStyle: TextStyle(
                color: _selectedFilter == filter ? const Color(0xFFFB6E1E) : Colors.white,
              ),
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Build the product list
  Widget _buildProductList(List<Map<String, dynamic>> products) {
    final processedProducts = _getFilteredAndSortedProducts(products);

    if (processedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: processedProducts.length,
      itemBuilder: (context, index) {
        final product = processedProducts[index];
        final daysUntilExpiry = product['expiryDate'].difference(DateTime.now()).inDays;
        return ProductCard(
          id: product['id'],
          name: product['name'],
          expiryDate: product['expiryDate'],
          quantity: product['quantity'],
          onEdit: (id) {
            // Handle edit action
          },
          onDelete: (id) {
            // Handle delete action
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF082969),
              Color(0xFF070625),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with "Home" and notifications
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Search + Sort
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildSearchBar()),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: _buildSortDropdown()),
                  ],
                ),
              ),
              // Filter chips
              _buildFilterChips(),
              // Product list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('products').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFB6E1E),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final products = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        ...data,
                        'id': doc.id,
                        'expiryDate': _parseDate(data['expiryDate']),
                        'createdAt': data['createdAt'] != null
                            ? _parseDate(data['createdAt'])
                            : DateTime.now(),
                        'quantity': data['quantity'] ?? 0, // Default to 0 if null
                      };
                    }).toList();

                    return _buildProductList(products);
                  },
                ),
              ),
            ],
          ),
        ),
      )
          : const ProfilePage(), // If _currentIndex == 1 or 2, show ProfilePage
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}