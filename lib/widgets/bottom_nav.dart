import 'package:flutter/material.dart';
import 'package:expirydatetracker/theme/app_theme.dart';
import 'package:expirydatetracker/screens/add_product_page.dart';


class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      // We now have 3 items: 0 => Home, 1 => Add, 2 => Profile
      currentIndex: currentIndex,
      onTap: (index) async {
        // If user taps the middle item => open AddProductPage
        if (index == 1) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductPage()),
          );
          // If you need to refresh HomeScreen or do something with 'result', handle it here.
        } else {
          // Otherwise (Home or Profile), just switch tabs
          onTap(index);
        }
      },
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.secondaryColor.withOpacity(0.7),
      backgroundColor: const Color(0xFFFB6E1E),
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      selectedIconTheme: const IconThemeData(
        size: 28,
        color: AppTheme.primaryColor,
      ),
      unselectedIconTheme: IconThemeData(
        size: 24,
        color: AppTheme.secondaryColor.withOpacity(0.7),
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Add',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
