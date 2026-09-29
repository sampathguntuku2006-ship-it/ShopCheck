import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/about_screen.dart';
import '../screens/add_edit_shop_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/login_screen.dart';
import '../screens/map_screen.dart';
import '../screens/my_shops_screen.dart';
import '../screens/owner_dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

class AppMenuButton extends StatelessWidget {
  final Function(int)? onSelectTab;

  const AppMenuButton({super.key, this.onSelectTab});

  Future<void> _handleRoleSwitch(BuildContext context, UserRole targetRole) async {
    await AuthService().switchRole(targetRole);
    if (!context.mounted) return;

    // Pop any pushed screens so user sees the newly rendered shell
    Navigator.of(context).popUntil((route) => route.isFirst);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${targetRole.displayName} mode'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleMyLocation(BuildContext context) async {
    final result = await LocationService().requestLocationDetailed(requestIfNotGranted: true);
    if (!context.mounted) return;

    if (onSelectTab != null) {
      onSelectTab!(2); // Switch to Map tab
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.position != null ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out of ShopCheck?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await AuthService().logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;

    return ValueListenableBuilder<User?>(
      valueListenable: AuthService().userNotifier,
      builder: (context, user, _) {
        final isOwner = user?.role == UserRole.shopOwner;

        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: onSurfaceColor),
          tooltip: 'App Menu',
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) async {
            switch (value) {
              case 'ai_assistant':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                break;
              case 'profile':
                if (onSelectTab != null) {
                  onSelectTab!(isOwner ? 3 : 4);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }
                break;
              case 'favorites':
                if (onSelectTab != null) {
                  onSelectTab!(3);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                }
                break;
              case 'my_location':
                await _handleMyLocation(context);
                break;
              case 'dashboard':
                if (onSelectTab != null) {
                  onSelectTab!(0);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardScreen()));
                }
                break;
              case 'my_shops':
                if (onSelectTab != null) {
                  onSelectTab!(1);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyShopsScreen()));
                }
                break;
              case 'add_shop':
                if (onSelectTab != null) {
                  onSelectTab!(2);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditShopScreen()));
                }
                break;
              case 'help':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                break;
              case 'about':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                break;
              case 'settings':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                break;
              case 'switch_to_owner':
                await _handleRoleSwitch(context, UserRole.shopOwner);
                break;
              case 'switch_to_customer':
                await _handleRoleSwitch(context, UserRole.customer);
                break;
              case 'logout':
                await _handleLogout(context);
                break;
            }
          },
          itemBuilder: (ctx) {
            if (isOwner) {
              return [
                _buildMenuItem(context, 'ai_assistant', Icons.auto_awesome_rounded, 'ShopCheck AI', color: const Color(0xFF16A34A)),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'profile', Icons.person_rounded, 'My Profile'),
                _buildMenuItem(context, 'dashboard', Icons.dashboard_rounded, 'Dashboard'),
                _buildMenuItem(context, 'my_shops', Icons.store_mall_directory_rounded, 'My Shops'),
                _buildMenuItem(context, 'add_shop', Icons.add_business_rounded, 'Add Shop'),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'help', Icons.help_outline_rounded, 'Help & Support'),
                _buildMenuItem(context, 'about', Icons.info_outline_rounded, 'About ShopCheck'),
                _buildMenuItem(context, 'settings', Icons.settings_outlined, 'Settings'),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'switch_to_customer', Icons.shopping_bag_outlined, 'Switch to Customer', color: const Color(0xFF16A34A)),
                _buildMenuItem(context, 'logout', Icons.logout_rounded, 'Logout', color: const Color(0xFFDC2626)),
              ];
            } else {
              return [
                _buildMenuItem(context, 'ai_assistant', Icons.auto_awesome_rounded, 'ShopCheck AI', color: const Color(0xFF16A34A)),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'profile', Icons.person_rounded, 'My Profile'),
                _buildMenuItem(context, 'favorites', Icons.favorite_rounded, 'Favorites'),
                _buildMenuItem(context, 'my_location', Icons.my_location_rounded, 'My Location'),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'help', Icons.help_outline_rounded, 'Help & Support'),
                _buildMenuItem(context, 'about', Icons.info_outline_rounded, 'About ShopCheck'),
                _buildMenuItem(context, 'settings', Icons.settings_outlined, 'Settings'),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'switch_to_owner', Icons.storefront_rounded, 'Switch to Shop Owner', color: const Color(0xFFD97706)),
                _buildMenuItem(context, 'logout', Icons.logout_rounded, 'Logout', color: const Color(0xFFDC2626)),
              ];
            }
          },
        );
      },
    );
  }

  PopupMenuItem<String> _buildMenuItem(BuildContext context, String value, IconData icon, String title, {Color? color}) {
    final itemColor = color ?? Theme.of(context).colorScheme.onSurface;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: itemColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: itemColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

