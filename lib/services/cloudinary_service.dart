import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:expirydatetracker/config/cloudinary_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  late final CloudinaryPublic cloudinary;

  factory CloudinaryService() {
    return _instance;
  }

  CloudinaryService._internal() {
    // Initialize Cloudinary with config
    cloudinary = CloudinaryPublic(
        CloudinaryConfig.cloudName,
        CloudinaryConfig.uploadPreset,
        cache: false
    );
  }

  // Upload image to Cloudinary with compression
  Future<String?> uploadImage(File imageFile) async {
    try {
      // Compress the image before uploading
      final compressedImage = await FlutterImageCompress.compressWithFile(
        imageFile.path,
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
          imageFile.path,
          folder: CloudinaryConfig.folder,
          resourceType: CloudinaryResourceType.Image,
          publicId: fileName, // Use the unique filename
        ),
      );

      // Return the secure URL
      return response.secureUrl;
    } catch (e) {
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }

  // Helper to generate thumbnail URL
  static String getThumbnailUrl(String originalUrl, {int width = 300, int height = 300}) {
    // Extract the base path and file extension
    final uri = Uri.parse(originalUrl);
    final pathSegments = uri.pathSegments;

    // Construct the transformation URL
    // Format: https://res.cloudinary.com/{cloud_name}/image/upload/c_thumb,w_{width},h_{height}/{path}
    return originalUrl.replaceFirst(
      '/image/upload/',
      '/image/upload/c_fill,w_${width},h_${height},g_auto,q_auto,f_auto/',
    );
  }

  // Helper to get optimized image URL for display
  static String getOptimizedUrl(String originalUrl, {int width = 800}) {
    return originalUrl.replaceFirst(
      '/image/upload/',
      '/image/upload/c_scale,w_${width},q_auto,f_auto/',
    );
  }
}