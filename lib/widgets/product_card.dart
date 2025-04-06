import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:expirydatetracker/services/cloudinary_service.dart';

class ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final DateTime expiryDate;
  final int quantity;
  final String? photoUrl;
  final String category;
  final Function(String)? onEdit;
  final Function(String)? onDelete;
  final VoidCallback? onTap;

  const ProductCard({
    Key? key,
    required this.id,
    required this.name,
    required this.expiryDate,
    this.quantity = 0,
    this.photoUrl,
    this.category = 'Unknown',
    this.onEdit,
    this.onDelete,
    this.onTap,
  }) : super(key: key);

  // Calculate days until expiry
  int get daysUntilExpiry {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    return difference.inDays;
  }

  // Get color based on expiry date
  Color get expiryColor {
    if (daysUntilExpiry < 0) {
      return const Color(0xFFFF3B30); // Bright red for expired
    } else if (daysUntilExpiry <= 7) {
      return const Color(0xFFFF9500); // Orange for soon expiring
    } else if (daysUntilExpiry <= 30) {
      return const Color(0xFFFFCC00); // Yellow for warning
    } else {
      return const Color(0xFF34C759); // Green for safe
    }
  }

  // Get a matching gradient based on expiry status
  List<Color> get expiryGradient {
    if (daysUntilExpiry < 0) {
      return [const Color(0xFFFF3B30), const Color(0xFFFF5E3A)]; // Red gradient
    } else if (daysUntilExpiry <= 7) {
      return [const Color(0xFFFF9500), const Color(0xFFFFB340)]; // Orange gradient
    } else if (daysUntilExpiry <= 30) {
      return [const Color(0xFFFFCC00), const Color(0xFFFFD60A)]; // Yellow gradient
    } else {
      return [const Color(0xFF34C759), const Color(0xFF30D158)]; // Green gradient
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final expiryStatus = daysUntilExpiry < 0
        ? 'Expired ${-daysUntilExpiry}d ago'
        : '${daysUntilExpiry}d left';

    return Card(
      elevation: 8,
      shadowColor: expiryColor.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white.withOpacity(0.8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with status overlay
              Stack(
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: photoUrl != null
                        ? Hero(
                      tag: 'product-image-$id',
                      child: CachedNetworkImage(
                        imageUrl: CloudinaryService.getThumbnailUrl(
                          photoUrl!,
                          width: 400,
                          height: 200,
                        ),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: expiryColor,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                        : Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                  // Category label
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  // Expiry status badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: expiryGradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: expiryColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        expiryStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  // Quantity badge if more than 1
                  if (quantity > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Qty: $quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Product Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Expiry progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: daysUntilExpiry < 0
                            ? 0
                            : daysUntilExpiry > 60
                            ? 1
                            : daysUntilExpiry / 60,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(expiryColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date and action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(expiryDate),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Action buttons
                        Row(
                          children: [
                            if (onEdit != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  onPressed: () => onEdit!(id),
                                  tooltip: 'Edit product',
                                  iconSize: 22,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (onDelete != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outlined, color: Colors.red),
                                  onPressed: () => onDelete!(id),
                                  tooltip: 'Delete product',
                                  iconSize: 22,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}