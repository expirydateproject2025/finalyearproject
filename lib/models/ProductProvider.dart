import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expirydatetracker/models/product_model.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  ProductProvider() {
    _loadProducts();
  }

  // Public getters
  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Statistics getters for profile page
  int get totalItems => _products.length;

  int get expiringSoon {
    final now = DateTime.now();
    final inOneWeek = now.add(const Duration(days: 7));
    return _products.where((p) =>
    p.expiryDate.isAfter(now) &&
        p.expiryDate.isBefore(inOneWeek)
    ).length;
  }

  int get trackedThisMonth {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    return _products.where((p) =>
        p.createdAt.isAfter(firstDayOfMonth)
    ).length;
  }

  // Expiry helpers
  List<Product> get expiredProducts =>
      _products.where((p) => p.isExpired).toList();

  List<Product> get productsExpiringThisWeek {
    final now = DateTime.now();
    final inOneWeek = now.add(const Duration(days: 7));
    return _products.where((p) =>
    p.expiryDate.isAfter(now) &&
        p.expiryDate.isBefore(inOneWeek)
    ).toList();
  }

  List<Product> get productsExpiringThisMonth {
    final now = DateTime.now();
    final inOneMonth = now.add(const Duration(days: 30));
    return _products.where((p) =>
    p.expiryDate.isAfter(now) &&
        p.expiryDate.isBefore(inOneMonth)
    ).toList();
  }

  // Category statistics
  Map<String, int> get productsByCategory {
    final categoryMap = <String, int>{};
    for (final product in _products) {
      final category = product.category;
      if (categoryMap.containsKey(category)) {
        categoryMap[category] = (categoryMap[category] ?? 0) + 1;
      } else {
        categoryMap[category] = 1;
      }
    }
    return categoryMap;
  }

  // Monthly tracking statistics
  Map<String, int> getMonthlyTrackingStats(int monthsBack) {
    final statsMap = <String, int>{};
    final now = DateTime.now();

    for (int i = 0; i < monthsBack; i++) {
      final month = now.month - i;
      final year = now.year - (month <= 0 ? 1 : 0);
      final adjustedMonth = month <= 0 ? month + 12 : month;

      final monthStart = DateTime(year, adjustedMonth, 1);
      final monthEnd = adjustedMonth < 12
          ? DateTime(year, adjustedMonth + 1, 1).subtract(const Duration(days: 1))
          : DateTime(year + 1, 1, 1).subtract(const Duration(days: 1));

      final monthName = _getMonthName(adjustedMonth);
      final count = _products.where((p) =>
      p.createdAt.isAfter(monthStart) &&
          p.createdAt.isBefore(monthEnd.add(const Duration(days: 1)))
      ).length;

      statsMap['$monthName $year'] = count;
    }

    return statsMap;
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }

  // Load products from Firestore
  Future<void> _loadProducts() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final stream = Product.streamUserProducts();

      // Subscribe to the stream
      stream.listen(
              (productsList) {
            _products = productsList;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = 'Failed to load products: $e';
            _isLoading = false;
            notifyListeners();
          }
      );
    } catch (e) {
      _error = 'Failed to initialize products stream: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a product
  Future<void> addProduct(Product product) async {
    try {
      await product.save();
      // No need to manually update _products as the stream will handle it
    } catch (e) {
      _error = 'Failed to add product: $e';
      notifyListeners();
    }
  }

  // Update a product
  Future<void> updateProduct(Product product) async {
    try {
      await product.save();
      // No need to manually update _products as the stream will handle it
    } catch (e) {
      _error = 'Failed to update product: $e';
      notifyListeners();
    }
  }

  // Delete a product
  Future<void> deleteProduct(Product product) async {
    try {
      await product.delete();
      // No need to manually update _products as the stream will handle it
    } catch (e) {
      _error = 'Failed to delete product: $e';
      notifyListeners();
    }
  }

  // Get enhanced product statistics for dashboard
  Map<String, dynamic> getEnhancedStatistics() {
    // Count products by status
    final expired = expiredProducts.length;
    final expiringThisWeek = productsExpiringThisWeek.length;
    final expiringThisMonth = productsExpiringThisMonth.length;
    final healthy = _products.length - expired - expiringThisWeek - expiringThisMonth;

    // Get most common categories
    final sortedCategories = productsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories.take(3).map((e) => {
      'category': e.key,
      'count': e.value,
    }).toList();

    // Get recently added products
    final recentlyAdded = List<Product>.from(_products)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Get soon to expire products
    final soonToExpire = _products
        .where((p) => !p.isExpired)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return {
      'counts': {
        'total': _products.length,
        'expired': expired,
        'expiringThisWeek': expiringThisWeek,
        'expiringThisMonth': expiringThisMonth,
        'healthy': healthy,
      },
      'topCategories': topCategories,
      'recentlyAdded': recentlyAdded.take(5).toList(),
      'soonToExpire': soonToExpire.take(5).toList(),
      'monthlyTracking': getMonthlyTrackingStats(6),
    };
  }
}