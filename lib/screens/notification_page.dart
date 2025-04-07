import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FirestoreService _firestoreService;
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _firestoreService = FirestoreService();
    _notificationService = NotificationService();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0D0A4A), // Dark blue background
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFDA4E00),
                      Color(0xFFFFD834),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withOpacity(0.6),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                      ),
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Expiring Soon'),
                        Tab(text: 'Expired'),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductList(_firestoreService.getProducts()),
                    _buildProductList(_firestoreService.getProductsExpiringSoon()),
                    _buildProductList(_firestoreService.getExpiredProducts()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new product logic
        },
        backgroundColor: const Color(0xFFDA4E00),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildProductList(Stream<List<Product>> productsStream) {
    return StreamBuilder<List<Product>>(
      stream: productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFFD834),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading products',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          );
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return Center(
            child: Text(
              'No products found',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    // Determine card colors and icons based on expiry status
    Color cardColor;
    Color iconBackgroundColor;
    IconData statusIcon;
    String statusText;
    Color statusTextColor;

    if (product.isExpired) {
      statusText = 'Expired';
      statusTextColor = Colors.red.shade800;
      cardColor = Colors.red.shade50;
      iconBackgroundColor = Colors.red.shade100;
      statusIcon = Icons.warning_rounded;
    } else if (product.daysRemaining <= 1) {
      statusText = 'Expires Today/Tomorrow';
      statusTextColor = Colors.orange.shade800;
      cardColor = Colors.orange.shade50;
      iconBackgroundColor = Colors.orange.shade100;
      statusIcon = Icons.timer;
    } else if (product.daysRemaining <= 7) {
      statusText = 'Expires This Week';
      statusTextColor = Colors.amber.shade800;
      cardColor = Colors.amber.shade50;
      iconBackgroundColor = Colors.amber.shade100;
      statusIcon = Icons.access_time;
    } else if (product.daysRemaining <= 30) {
      statusText = 'Expires This Month';
      statusTextColor = Colors.blue.shade800;
      cardColor = Colors.blue.shade50;
      iconBackgroundColor = Colors.blue.shade100;
      statusIcon = Icons.calendar_today;
    } else {
      statusText = 'Valid';
      statusTextColor = Colors.green.shade800;
      cardColor = Colors.green.shade50;
      iconBackgroundColor = Colors.green.shade100;
      statusIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusTextColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Expires: ${_formatDate(product.expiryDate)}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // More Options Button
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showOptionsDialog(product);
                  },
                ),
              ],
            ),
          ),

          // Status Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: iconBackgroundColor.withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications,
                  size: 16,
                  color: statusTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Options for ${product.name}'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to details page
            },
            child: const Row(
              children: [
                Icon(Icons.visibility),
                SizedBox(width: 8),
                Text('View Details'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              if (product.id == null) return;

              if (product.notificationsScheduled) {
                await _notificationService.cancelProductNotifications(product.id!);
                _showSnackBar('Notifications disabled');
              } else {
                await _notificationService.scheduleExpiryNotification(
                  productId: product.id!,
                  productName: product.name,
                  expiryDate: product.expiryDate,
                );
                _showSnackBar('Notifications enabled');
              }
            },
            child: Row(
              children: [
                Icon(
                  product.notificationsScheduled
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                  color: product.notificationsScheduled
                      ? Colors.grey
                      : const Color(0xFFDA4E00),
                ),
                const SizedBox(width: 8),
                Text(
                  product.notificationsScheduled
                      ? 'Disable Notifications'
                      : 'Enable Notifications',
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(product);
            },
            child: const Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (product.id != null) {
                await _firestoreService.deleteProduct(product.id!);
                _showSnackBar('Product deleted');
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}