import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/app_menu_button.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onRoleChanged;

  const ProfileScreen({super.key, this.onRoleChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  Future<void> _handleRoleSwitch(UserRole newRole) async {
    await _authService.switchRole(newRole);
    if (!mounted) return;
    widget.onRoleChanged?.call();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${newRole.displayName} mode'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditProfileDialog(User user) {
    final controller = TextEditingController(text: user.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await _authService.updateProfile(name: newName);
              if (!mounted) return;
              nav.pop();
              setState(() {});
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  backgroundColor: Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password (min. 6 chars)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final res = await _authService.changePassword(
                oldPassword: oldController.text,
                newPassword: newController.text,
              );
              if (!mounted) return;
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.isSuccess ? 'Password changed successfully' : (res.errorMessage ?? 'Failed to change password')),
                  backgroundColor: res.isSuccess ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
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
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: _authService.userNotifier,
      builder: (context, user, _) {
        final currentRole = user?.role ?? UserRole.customer;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text(
              'My Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            actions: const [
              AppMenuButton(),
              SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // User Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: currentRole == UserRole.shopOwner
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentRole == UserRole.shopOwner
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFF86EFAC),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          currentRole == UserRole.shopOwner
                              ? Icons.store_rounded
                              : Icons.person_rounded,
                          size: 38,
                          color: currentRole == UserRole.shopOwner
                              ? const Color(0xFFD97706)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user?.effectiveName ?? 'User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? 'Unknown Phone',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentRole == UserRole.shopOwner
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentRole.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: currentRole == UserRole.shopOwner
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Account Information Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Account Role', currentRole.displayName),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildInfoRow('Registered Phone', user?.phone ?? 'N/A'),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildInfoRow('Account Status', 'Active & Verified', valueColor: const Color(0xFF16A34A)),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildInfoRow('Member Since', user != null ? '${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}' : '2026-01-01'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Role Switcher Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Role & Mode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Switch between Customer search and Shop Owner management instantly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: currentRole == UserRole.customer
                                  ? null
                                  : () => _handleRoleSwitch(UserRole.customer),
                              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                              label: const Text('Customer'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: currentRole == UserRole.customer
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFCBD5E1),
                                  width: currentRole == UserRole.customer ? 2 : 1,
                                ),
                                backgroundColor: currentRole == UserRole.customer
                                    ? const Color(0xFFF0FDF4)
                                    : Colors.white,
                                foregroundColor: currentRole == UserRole.customer
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF475569),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: currentRole == UserRole.shopOwner
                                  ? null
                                  : () => _handleRoleSwitch(UserRole.shopOwner),
                              icon: const Icon(Icons.storefront_outlined, size: 18),
                              label: const Text('Shop Owner'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: currentRole == UserRole.shopOwner
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFCBD5E1),
                                  width: currentRole == UserRole.shopOwner ? 2 : 1,
                                ),
                                backgroundColor: currentRole == UserRole.shopOwner
                                    ? const Color(0xFFFEF3C7)
                                    : Colors.white,
                                foregroundColor: currentRole == UserRole.shopOwner
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF475569),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Account Actions
                Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: () {
                          if (user != null) _showEditProfileDialog(user);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF7C3AED)),
                        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: _showChangePasswordDialog,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: Color(0xFF0F172A)),
                        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                      ListTile(
                        leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF16A34A)),
                        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Log Out Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? const Color(0xFF0F172A))),
      ],
    );
  }
}
