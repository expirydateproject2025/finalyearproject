import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expirydatetracker/navigation/bottom_nav_controller.dart';
import 'package:expirydatetracker/screens/home_screen.dart';
import 'package:expirydatetracker/screens/profile_page.dart';
import 'package:expirydatetracker/widgets/animated_bottom_nav.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BottomNavController>(
        builder: (context, controller, child) {
          return IndexedStack(
            index: controller.currentIndex,
            children: const [
              HomeScreen(),
              SizedBox.shrink(), // Placeholder for add button
              ProfilePage(),
            ],
          );
        },
      ),
      bottomNavigationBar: const AnimatedBottomNav(),
    );
  }
}