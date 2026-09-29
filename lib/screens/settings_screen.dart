import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();

  bool _statusNotifications = true;
  bool _promoNotifications = false;
  bool _highAccuracyGps = true;
  bool _showMapGrid = true;
  String _defaultCity = 'All India';

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final currentRole = user?.role ?? UserRole.customer;
    final hasLocation = _locationService.hasLocation;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Appearance (Theme Support)
            _buildSectionHeader('Appearance', Icons.palette_outlined, const Color(0xFF8B5CF6)),
            const SizedBox(height: 8),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService().themeModeNotifier,
              builder: (context, currentMode, _) {
                return Material(
                  color: cardBg,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderColor),
                  ),
                  child: RadioGroup<ThemeMode>(
                    groupValue: currentMode,
                    onChanged: (mode) {
                      if (mode != null) ThemeService().setThemeMode(mode);
                    },
                    child: Column(
                      children: [
                        const RadioListTile<ThemeMode>(
                          title: Text('System Default', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Follow Android device system theme', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          value: ThemeMode.system,
                          activeColor: Color(0xFF16A34A),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                        const RadioListTile<ThemeMode>(
                          title: Text('Light', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Always use crisp bright theme', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          value: ThemeMode.light,
                          activeColor: Color(0xFF16A34A),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                        const RadioListTile<ThemeMode>(
                          title: Text('Dark', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Always use high-contrast dark theme', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          value: ThemeMode.dark,
                          activeColor: Color(0xFF16A34A),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                        SwitchListTile(
                          title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          currentMode == ThemeMode.system
                              ? 'System Default (${isDark ? "Dark" : "Light"} active)'
                              : (currentMode == ThemeMode.dark ? 'Enabled' : 'Disabled'),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        value: currentMode == ThemeMode.dark,
                        activeTrackColor: const Color(0xFF16A34A),
                        onChanged: (val) {
                          ThemeService().setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
            const SizedBox(height: 20),

            // Section 1: Notifications
            _buildSectionHeader('Notifications', Icons.notifications_active_rounded, const Color(0xFF2563EB)),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Store Status Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Get notified when favorite stores open or change hours', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    value: _statusNotifications,
                    activeTrackColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _statusNotifications = val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    title: const Text('Promotional Updates', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Periodic recommendations and new shop alerts', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    value: _promoNotifications,
                    activeTrackColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _promoNotifications = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Location Permission Information
            _buildSectionHeader('Location & GPS', Icons.location_on_rounded, const Color(0xFF16A34A)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasLocation ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasLocation ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Text(
                          hasLocation ? 'GPS ACTIVE' : 'FALLBACK (INDIA)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: hasLocation ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final res = await _locationService.requestLocationDetailed(requestIfNotGranted: true);
                          if (!mounted) return;
                          setState(() {});
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.position != null ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Check GPS'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ShopCheck uses device location to calculate driving distance and sort shops nearest to you. If permission is denied, India default coordinates (20.5937° N, 78.9629° E) are used.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Map Settings
            _buildSectionHeader('Map Settings', Icons.map_rounded, const Color(0xFF0F172A)),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('High Accuracy GPS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Enhance pinpoint precision on the map canvas', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    value: _highAccuracyGps,
                    activeTrackColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _highAccuracyGps = val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    title: const Text('Show Map Gridlines', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Display latitude/longitude grid markings', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    value: _showMapGrid,
                    activeTrackColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _showMapGrid = val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ListTile(
                    title: const Text('Default Region Centroid', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(_defaultCity, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    trailing: DropdownButton<String>(
                      value: _defaultCity,
                      underline: const SizedBox(),
                      items: ['All India', 'Hyderabad', 'Bengaluru', 'Mumbai', 'Delhi', 'Chennai', 'Kolkata', 'Pune']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _defaultCity = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: Account Settings
            _buildSectionHeader('Account Settings', Icons.person_rounded, const Color(0xFF7C3AED)),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_rounded, color: Color(0xFF64748B)),
                    title: const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(user?.phone ?? 'Not signed in', style: const TextStyle(fontSize: 12)),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: const Icon(Icons.badge_rounded, color: Color(0xFF64748B)),
                    title: const Text('Current Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(currentRole.displayName, style: const TextStyle(fontSize: 12)),
                    trailing: TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final newRole = currentRole == UserRole.customer ? UserRole.shopOwner : UserRole.customer;
                        await _authService.switchRole(newRole);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${newRole.displayName} mode'),
                            backgroundColor: const Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(
                        currentRole == UserRole.customer ? 'Switch to Owner' : 'Switch to Customer',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 5: About & Help Links
            _buildSectionHeader('Support & Info', Icons.info_outline_rounded, const Color(0xFF0F172A)),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB)),
                    title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: const Icon(Icons.storefront_rounded, color: Color(0xFF16A34A)),
                    title: const Text('About ShopCheck', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
