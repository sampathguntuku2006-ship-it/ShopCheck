import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'owner_shell.dart';

/// Bottom navigation shell for Customers: Home, Search, Map, Favorites, Profile
class CustomerShell extends StatefulWidget {
  final int initialTab;

  const CustomerShell({super.key, this.initialTab = 0});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: AuthService().userNotifier,
      builder: (context, user, child) {
        if (user?.role == UserRole.shopOwner) {
          return const OwnerShell(key: ValueKey('owner_shell'));
        }

        final screens = [
          const HomeScreen(),
          const SearchScreen(),
          const MapScreen(),
          const FavoritesScreen(),
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
            indicatorColor: const Color(0xFFDCFCE7),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF16A34A)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded, color: Color(0xFF16A34A)),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF16A34A)),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded),
                selectedIcon: Icon(Icons.favorite_rounded, color: Color(0xFFEF4444)),
                label: 'Favorites',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF16A34A)),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
