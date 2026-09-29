import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _showContactSupportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact Support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text('We respond within 24 hours', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('How can we help you?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe your issue or feedback...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support request submitted. Thank you!'),
                        backgroundColor: Color(0xFF16A34A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Message', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.help_center_rounded, color: Colors.white, size: 40),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How can we help?',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Guides, tutorials, FAQs and live contact for ShopCheck.',
                          style: TextStyle(color: Color(0xFFDCFCE7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Getting Started
            _buildSection(
              title: 'Getting Started',
              icon: Icons.explore_rounded,
              color: const Color(0xFF2563EB),
              items: const [
                _HelpItem(
                  question: 'How to search for a shop',
                  answer: 'Use the search bar on Customer Home or the Search tab. You can search by store name, category (e.g. Grocery, Pharmacy), or city.',
                ),
                _HelpItem(
                  question: 'How to check whether a shop is open',
                  answer: 'Each shop card displays a live OPEN, CLOSED, or TEMPORARILY CLOSED badge calculated from current device time and the store\'s weekly schedule.',
                ),
                _HelpItem(
                  question: 'How to view a shop on the map',
                  answer: 'Switch to the Map tab or tap any shop card to view its exact pinned location on the interactive map with city presets and zoom controls.',
                ),
                _HelpItem(
                  question: 'How to get directions',
                  answer: 'Open any shop details page and tap "Get Directions". ShopCheck connects directly with Google Maps or your web browser to provide turn-by-turn navigation.',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: For Shop Owners
            _buildSection(
              title: 'For Shop Owners',
              icon: Icons.storefront_rounded,
              color: const Color(0xFFD97706),
              items: const [
                _HelpItem(
                  question: 'How to add a shop',
                  answer: 'In Shop Owner mode, tap "+ Add Shop" in the bottom navigation or the Quick Action button on your Dashboard. Fill in the store name, category, address, coordinates, and hours.',
                ),
                _HelpItem(
                  question: 'How to edit a shop',
                  answer: 'Navigate to "My Shops", locate the shop, and tap the edit button to update its details, schedule, or location at any time.',
                ),
                _HelpItem(
                  question: 'How to add shop location',
                  answer: 'On the Add/Edit Shop screen, locate the "Shop Location" section. You can view coordinates, drag or tap on the map canvas, and tap "Confirm Location".',
                ),
                _HelpItem(
                  question: 'How to use current GPS location',
                  answer: 'Tap "Use My Current Location". If GPS permission is granted, your device\'s latitude and longitude will automatically be pinned to your store.',
                ),
                _HelpItem(
                  question: 'How to temporarily close a shop',
                  answer: 'In the Edit Shop screen, toggle "Temporarily Closed" and enter an optional reason (e.g., Renovation or Holiday). This updates customer screens immediately.',
                ),
                _HelpItem(
                  question: 'How to update opening hours',
                  answer: 'In the Weekly Schedule section, configure open/close hours for each day of the week or mark specific days as closed.',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Location Help
            _buildSection(
              title: 'Location & GPS Help',
              icon: Icons.location_on_rounded,
              color: const Color(0xFF16A34A),
              items: const [
                _HelpItem(
                  question: 'How location permission works',
                  answer: 'ShopCheck uses device GPS solely to show shops nearest to you and calculate driving distances. Permission is requested only when necessary.',
                ),
                _HelpItem(
                  question: 'What happens if GPS permission is denied',
                  answer: 'If GPS permission is denied, ShopCheck gracefully falls back to the India center centroid (20.5937° N, 78.9629° E). You can still search shops and pick locations manually.',
                ),
                _HelpItem(
                  question: 'How to manually select a shop location',
                  answer: 'In Add/Edit Shop, tap "Select Exact Location on Map". Tap anywhere on the canvas or pick a city preset (Hyderabad, Bengaluru, Mumbai, etc.) and tap Confirm.',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 4: Frequently Asked Questions
            _buildSection(
              title: 'Frequently Asked Questions (FAQ)',
              icon: Icons.quiz_rounded,
              color: const Color(0xFF7C3AED),
              items: const [
                _HelpItem(
                  question: 'Why is a shop showing CLOSED?',
                  answer: 'A shop is marked CLOSED when the current time is outside its configured weekly hours, or if the shop owner has enabled temporary closure.',
                ),
                _HelpItem(
                  question: 'How is OPEN/CLOSED calculated?',
                  answer: 'Opening hours are checked dynamically against your current day of the week and local clock time down to the minute.',
                ),
                _HelpItem(
                  question: 'Why can\'t I see my shop?',
                  answer: 'Ensure you are signed in with the same phone number that created the shop. Check "My Shops" in the Shop Owner Hub.',
                ),
                _HelpItem(
                  question: 'Why is my location unavailable?',
                  answer: 'Check that location services (GPS) are toggled ON in your device system settings and that ShopCheck has location permissions.',
                ),
                _HelpItem(
                  question: 'How do I change my role?',
                  answer: 'Open the three-dot menu (...) on the top right or go to My Profile, then tap "Switch to Shop Owner" or "Switch to Customer". The UI updates immediately.',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Contact Support Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.headset_mic_rounded, color: Color(0xFF16A34A), size: 22),
                      SizedBox(width: 10),
                      Text('Still have questions?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is available 7 days a week to help customers and shop owners.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showContactSupportDialog(context),
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: const Text('Contact Support Team', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_HelpItem> items,
  }) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
        ),
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.question,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.answer,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HelpItem {
  final String question;
  final String answer;

  const _HelpItem({required this.question, required this.answer});
}
