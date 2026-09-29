import 'package:flutter/material.dart';
import 'help_support_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Privacy & Security', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Data Protection',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '• Passwords are cryptographically salted and hashed using SHA-256 before storage and are NEVER stored in plain text.\n'
                '• Shop location coordinates and schedules are stored securely.\n'
                '• GPS location is accessed only on-demand with your device permission and is never sold or shared with third parties.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Account Privacy',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Customer favorites and owner shops are isolated and authorized to your account only.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'About ShopCheck',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            const Text(
              'ShopCheck',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            const Text(
              '"Check before you travel."',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF16A34A), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Version 1.2.0 (Build 2026)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ShopCheck helps customers check shop availability, opening hours, location and directions before travelling.\n\n'
                    'Never waste a trip to a closed store again. With real-time status indicators, temporary closure alerts, live interactive maps, and turn-by-turn navigation, ShopCheck bridges neighborhood businesses and local customers.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB)),
                    title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Color(0xFF16A34A)),
                    title: const Text('Privacy Information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () => _showPrivacyDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '© 2026 ShopCheck. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
