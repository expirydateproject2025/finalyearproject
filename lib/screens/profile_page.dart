import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF711F), // Sky blue
                Color(0xFFDA4E00), // Darker blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4, // Slight shadow for separation
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF56CCF2), // Sky blue
              Color(0xFF2F80ED), // Darker blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'TEST',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero, // Remove the default padding
                  children: [
                    // Settings ListTile
                    Container(
                      margin: const EdgeInsets.only(bottom: 10), // Add margin for spacing
                      decoration: BoxDecoration(
                        color: Color(0xFFFB6E1E), // Light Orange color
                        borderRadius: BorderRadius.circular(10), // Rounded corners
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.settings, color: Colors.white),
                        title: const Text(
                          'Settings',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onTap: () {},
                      ),
                    ),
                    // Notification Settings ListTile
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Color(0xFFFB6E1E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.notifications, color: Colors.white),
                        title: const Text(
                          'Notification Settings',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onTap: () {},
                      ),
                    ),
                    // Help & Support ListTile
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Color(0xFFFB6E1E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.help, color: Colors.white),
                        title: const Text(
                          'Help & Support',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onTap: () {},
                      ),
                    ),
                    // Logout ListTile
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Color(0xFFFB6E1E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.white),
                        title: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onTap: () async {
                          // Sign out the user
                          await FirebaseAuth.instance.signOut();

                          // Navigate to the login screen
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                                (route) => false,
                          );
                        },
                      ),
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
