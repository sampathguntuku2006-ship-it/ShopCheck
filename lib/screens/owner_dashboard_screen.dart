import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/offline_banner.dart';
import 'add_edit_shop_screen.dart';
import 'chat_screen.dart';
import 'my_shops_screen.dart';
import 'shop_details_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final Function(int)? onTabChangeRequested;

  const OwnerDashboardScreen({super.key, this.onTabChangeRequested});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final ownerPhone = _authService.currentUser?.phone ?? '';

    return ValueListenableBuilder<List<Shop>>(
      valueListenable: _databaseService.shopsNotifier,
      builder: (context, shops, child) {
        final myShops = _databaseService.getShopsByOwner(ownerPhone);
        final totalShops = myShops.length;
        final openShops = myShops.where((s) => s.getStatus().isOpen).length;
        final closedShops = myShops.where((s) => !s.getStatus().isOpen && !s.isTemporarilyClosed).length;
        final tempClosedShops = myShops.where((s) => s.isTemporarilyClosed).length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shop Owner Hub',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Manage your stores & live hours',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            actions: [
              AppMenuButton(
                onSelectTab: widget.onTabChangeRequested,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: DatabaseService().cloudSyncNotifier,
                  builder: (context, isSyncActive, _) {
                    if (!isSyncActive) {
                      return const OfflineBanner();
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Welcome Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back, Shop Owner',
                        style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ownerPhone.isNotEmpty ? ownerPhone : 'Shop Owner',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (widget.onTabChangeRequested != null) {
                              widget.onTabChangeRequested!(2); // Switch to Add Shop tab
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddEditShopScreen()),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_business_rounded, size: 18),
                          label: const Text('Add New Shop', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Status Statistics (Total Shops, Open Now, Closed, Temporarily Closed)
                Column(
                  children: [
                    Row(
                      children: [
                        _buildMetricCard('Total Shops', '$totalShops', const Color(0xFF0F172A), Icons.store_rounded),
                        const SizedBox(width: 10),
                        _buildMetricCard('Open Now', '$openShops', const Color(0xFF16A34A), Icons.check_circle_rounded),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMetricCard('Closed', '$closedShops', const Color(0xFFDC2626), Icons.cancel_rounded),
                        const SizedBox(width: 10),
                        _buildMetricCard('Temporarily Closed', '$tempClosedShops', const Color(0xFFD97706), Icons.pause_circle_rounded),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Quick Actions Section
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickActionCard(
                        title: '+ Add Shop',
                        subtitle: 'Register new store',
                        icon: Icons.add_business_rounded,
                        color: const Color(0xFF16A34A),
                        onTap: () {
                          if (widget.onTabChangeRequested != null) {
                            widget.onTabChangeRequested!(2);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddEditShopScreen()),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionCard(
                        title: 'My Shops',
                        subtitle: 'View store catalog',
                        icon: Icons.store_mall_directory_rounded,
                        color: const Color(0xFF0F172A),
                        onTap: () {
                          if (widget.onTabChangeRequested != null) {
                            widget.onTabChangeRequested!(1);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MyShopsScreen()),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionCard(
                        title: 'Manage Opening Hours',
                        subtitle: 'Set daily schedules',
                        icon: Icons.access_time_filled_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => _handleShopAction(context, myShops, 'schedule'),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionCard(
                        title: 'Update Shop Location',
                        subtitle: 'Set GPS coordinates',
                        icon: Icons.edit_location_alt_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => _handleShopAction(context, myShops, 'location'),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionCard(
                        title: 'Temporary Closure',
                        subtitle: 'Toggle store pause',
                        icon: Icons.pause_circle_filled_rounded,
                        color: const Color(0xFFD97706),
                        onTap: () => _handleShopAction(context, myShops, 'closure'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Shops Header
                Row(
                  children: [
                    const Text(
                      'My Stores',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    if (myShops.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          widget.onTabChangeRequested?.call(1); // Go to My Shops tab
                        },
                        child: const Text('View All', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (myShops.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.store_mall_directory_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text(
                          'No shops registered yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add your shop to display real-time open/closed status to customers.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (widget.onTabChangeRequested != null) {
                              widget.onTabChangeRequested!(2);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddEditShopScreen()),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Your First Shop'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFF16A34A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...myShops.take(3).map((shop) => _buildOwnerShopTile(shop)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'owner_dashboard_ai_fab',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text(
              'ShopCheck AI',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerShopTile(Shop shop) {
    final status = shop.getStatus();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(shop.categoryIcon, color: const Color(0xFF0F172A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${shop.category} • ${shop.city}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: status.borderColor),
                  ),
                  child: Text(
                    status.statusText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: status.statusColor),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Edit Shop',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditShopScreen(existingShop: shop)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShopDetailsScreen(shop: shop)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 155,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleShopAction(BuildContext context, List<Shop> myShops, String actionType) {
    if (myShops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a shop first before managing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (myShops.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditShopScreen(existingShop: myShops.first),
        ),
      );
      return;
    }

    // If multiple shops, show picker
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Shop to Manage',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...myShops.map((s) => ListTile(
                  leading: const Icon(Icons.storefront_rounded, color: Color(0xFF16A34A)),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${s.category} • ${s.city}'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditShopScreen(existingShop: s),
                      ),
                    );
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}
