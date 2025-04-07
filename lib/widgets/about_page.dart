import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About',
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070625), Color(0xFF120D9C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildAboutContent(),
        ),
      ),
    );
  }

  Widget _buildAboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App logo or icon
        Center(
          child: Image.asset(
            'assets/images/app_logo.png', // Make sure this asset exists
            height: 120,
            width: 120,
          ),
        ),
        const SizedBox(height: 24),

        // App title
        const Center(
          child: Text(
            'Expiry Date Tracker',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Version info
        const Center(
          child: Text(
            'Version 1.0.0',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // About sections
        _buildSection('What This App Does',
            'Expiry Date Tracker is your personal inventory management solution designed to help you keep track of product expiration dates, reduce waste, and save money.'),
        _buildSection('Features', [
          'Track Products: Easily add your items with their expiration dates',
          'Get Reminders: Receive notifications before your products expire',
          'View Statistics: See at a glance how many items you\'re tracking',
          'Reduce Waste: Make the most of your purchases',
          'Save Money: Stop throwing away expired products'
        ]),
        _buildSection('How to Use', [
          '1. Add products by tapping the "+" button',
          '2. Take a photo or select an image of your product',
          '3. Enter the product name and expiration date',
          '4. View your products by category or expiration date',
          '5. Get notified when products are about to expire'
        ]),
        _buildSection('Our Mission',
            'We\'re committed to helping you reduce waste, save money, and live more sustainably. By keeping track of expiration dates, you can make better decisions about what to use first and what to purchase next.'),
        const SizedBox(height: 24),

        // Contact info
        Center(
          child: TextButton(
            onPressed: () {
              // Add email link functionality
            },
            child: const Text(
              'Contact Us: support@expirydatetracker.com',
              style: TextStyle(
                color: Color(0xFFFFD834),
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSection(String title, dynamic content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFD834),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (content is String)
            Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            )
          else if (content is List<String>)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}