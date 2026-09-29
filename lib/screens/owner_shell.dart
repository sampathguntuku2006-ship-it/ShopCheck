import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'owner_dashboard_screen.dart';
import 'my_shops_screen.dart';
import 'add_edit_shop_screen.dart';
import 'profile_screen.dart';
import 'customer_shell.dart';

/// Bottom navigation shell for Shop Owners: Dashboard, My Shops, Add Shop, Profile
class OwnerShell extends StatefulWidget {
  final int initialTab;

  const OwnerShell({super.key, this.initialTab = 0});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: AuthService().userNotifier,
      builder: (context, user, child) {
        if (user?.role == UserRole.customer) {
          return const CustomerShell(key: ValueKey('customer_shell'));
        }

        final screens = [
          OwnerDashboardScreen(
            onTabChangeRequested: _navigateToTab,
          ),
          const MyShopsScreen(),
          const AddEditShopScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.white,
            elevation: 2,
            indicatorColor: const Color(0xFFFEF3C7),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFFD97706)),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_mall_directory_outlined),
                selectedIcon: Icon(Icons.store_mall_directory_rounded, color: Color(0xFFD97706)),
                label: 'My Shops',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_business_outlined),
                selectedIcon: Icon(Icons.add_business_rounded, color: Color(0xFFD97706)),
                label: 'Add Shop',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: Color(0xFFD97706)),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
