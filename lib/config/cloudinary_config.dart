class CloudinaryConfig {
  // Replace these with your actual Cloudinary credentials
  static const String cloudName = 'your_cloud_name'; // Replace with your cloud name
  static const String apiKey = 'your_api_key'; // Replace with your API key
  static const String apiSecret = 'your_api_secret'; // Replace with your API secret
  static const String uploadPreset = 'your_upload_preset'; // Replace with your upload preset
  static const String folder = 'expiry_products'; // Your folder name

  // Helper method to get the configuration as a map
  static Map<String, String> getConfig() {
    return {
      'cloud_name': cloudName,
      'api_key': apiKey,
      'api_secret': apiSecret,
      'upload_preset': uploadPreset,
    };
  }
}