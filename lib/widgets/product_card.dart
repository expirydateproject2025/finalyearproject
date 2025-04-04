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
      return Colors.red;
    } else if (daysUntilExpiry <= 7) {
      return Colors.orange;
    } else if (daysUntilExpiry <= 30) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: expiryColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () {
          // Default tap behavior if needed
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with Cloudinary optimization
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: photoUrl != null
                  ? CachedNetworkImage(
                imageUrl: CloudinaryService.getThumbnailUrl(
                  photoUrl!,
                  width: 400,
                  height: 200,
                ),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.error),
                  ),
                ),
              )
                  : Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            // Product Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: expiryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: expiryColor.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: expiryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(expiryDate),
                        style: TextStyle(
                          color: expiryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        daysUntilExpiry < 0
                            ? 'Expired ${-daysUntilExpiry} days ago'
                            : '${daysUntilExpiry} days left',
                        style: TextStyle(
                          color: expiryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (quantity > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Qty: $quantity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (onEdit != null)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => onEdit!(id),
                              tooltip: 'Edit product',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                            ),
                          const SizedBox(width: 8),
                          if (onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => onDelete!(id),
                              tooltip: 'Delete product',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
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
    );
  }
}