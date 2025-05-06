import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expirydatetracker/navigation/bottom_nav_controller.dart';
import 'package:expirydatetracker/screens/add_product_page.dart';

class AnimatedBottomNav extends StatelessWidget {
  const AnimatedBottomNav({
    super.key,
    this.backgroundColor = const Color(0xFFFB6E1E),
    this.selectedItemColor = Colors.white,
    this.unselectedItemColor = Colors.white70,
  });

  final Color backgroundColor;
  final Color selectedItemColor;
  final Color unselectedItemColor;

  @override
  Widget build(BuildContext context) {
    return Consumer<BottomNavController>(
      builder: (context, controller, child) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(1),
              topRight: Radius.circular(1),
            ),
            child: BottomNavigationBar(
              currentIndex: controller.currentIndex,
              onTap: (index) async {
                // If user taps the Add button (middle item)
                if (index == 1) {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const AddProductPage(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutCubic;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);
                        return SlideTransition(position: offsetAnimation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  );

                  // Optional: Handle any result returned from AddProductPage
                  if (result != null) {
                    // Handle the result if needed
                  }
                } else {
                  // For Home or Profile, just switch tabs with animation
                  controller.changePage(index);
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: backgroundColor,
              selectedItemColor: selectedItemColor,
              unselectedItemColor: unselectedItemColor,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              elevation: 0, // No elevation as we're using container shadow
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
              items: [
                _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0, controller.currentIndex),
                _buildNavItem(Icons.add_circle_outline, Icons.add_circle, 'Add', 1, controller.currentIndex),
                _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 2, controller.currentIndex),
              ],
            ),
          ),
        );
      },
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData icon,
      IconData activeIcon,
      String label,
      int index,
      int currentIndex
      ) {
    return BottomNavigationBarItem(
      icon: _AnimatedNavIcon(
        icon: icon,
        activeIcon: activeIcon,
        isActive: currentIndex == index,
        color: currentIndex == index ? selectedItemColor : unselectedItemColor,
      ),
      label: label,
    );
  }
}

// Custom animated icon widget for smooth transitions
class _AnimatedNavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final Color color;

  const _AnimatedNavIcon({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(
        begin: isActive ? 0.0 : 1.0,
        end: isActive ? 1.0 : 0.0,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Inactive icon with opacity animation
            Opacity(
              opacity: 1 - value,
              child: Icon(
                icon,
                color: color,
                size: 24 + (value * 4), // Small size animation
              ),
            ),
            // Active icon with opacity animation
            Opacity(
              opacity: value,
              child: Icon(
                activeIcon,
                color: color,
                size: 24 + (value * 4), // Small size animation
              ),
            ),
            // Animated indicator dot below the icon when active
            if (isActive)
              Positioned(
                bottom: -4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}