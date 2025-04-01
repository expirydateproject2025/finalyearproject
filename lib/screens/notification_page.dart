import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Expiring Soon'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductList(_firestoreService.getProducts()),
          _buildProductList(_firestoreService.getProductsExpiringSoon()),
          _buildProductList(_firestoreService.getExpiredProducts()),
        ],
      ),
    );
  }

  Widget _buildProductList(Stream<List<Product>> productsStream) {
    return StreamBuilder<List<Product>>(
      stream: productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        return ListView.builder(
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
    // Choose color based on expiry status
    Color statusColor;
    IconData statusIcon;

    if (product.isExpired) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
    } else if (product.daysRemaining <= 1) {
      statusColor = Colors.orange;
      statusIcon = Icons.timer;
    } else if (product.daysRemaining <= 7) {
      statusColor = Colors.amber;
      statusIcon = Icons.access_time;
    } else if (product.daysRemaining <= 30) {
      statusColor = Colors.blue;
      statusIcon = Icons.calendar_today;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Expires: ${_formatDate(product.expiryDate)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.notifications, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  product.expiryStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            if (value == 'view') {
              // Navigate to product detail
            } else if (value == 'delete') {
              await _firestoreService.deleteProduct(product.id);
            } else if (value == 'toggleNotifications') {
              if (product.notificationsScheduled) {
                await _notificationService.cancelProductNotifications(product.id);
              } else {
                await _notificationService.scheduleExpiryNotification(
                  productId: product.id,
                  productName: product.name,
                  expiryDate: product.expiryDate,
                );
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggleNotifications',
              child: Row(
                children: [
                  Icon(product.notificationsScheduled
                      ? Icons.notifications_off
                      : Icons.notifications_active),
                  SizedBox(width: 8),
                  Text(product.notificationsScheduled
                      ? 'Disable Notifications'
                      : 'Enable Notifications'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to product details
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}