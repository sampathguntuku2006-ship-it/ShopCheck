import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'add_edit_shop_screen.dart';
import 'shop_details_screen.dart';

class MyShopsScreen extends StatefulWidget {
  const MyShopsScreen({super.key});

  @override
  State<MyShopsScreen> createState() => _MyShopsScreenState();
}

class _MyShopsScreenState extends State<MyShopsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  Future<void> _handleToggleTemporaryClosure(Shop shop) async {
    final willClose = !shop.isTemporarilyClosed;
    String? reason;

    if (willClose) {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Temporarily close this shop?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to mark "${shop.name}" as temporarily closed for customers? Normal opening hours will be paused.'),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Renovation, Stock counting, Holiday',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      reason = reasonController.text.trim();
    }

    final ownerPhone = _authService.currentUser?.phone ?? '';
    final success = await _databaseService.toggleTemporaryClosure(
      shop.id,
      ownerPhone,
      reason: reason,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willClose
                  ? 'Shop marked as TEMPORARILY CLOSED'
                  : 'Shop reopened to normal schedule',
            ),
            backgroundColor: willClose ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update status. Permission denied.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteShop(Shop shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Shop', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${shop.name}"? This action cannot be undone.'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ownerPhone = _authService.currentUser?.phone ?? '';
      await _databaseService.deleteShop(shop.id, ownerPhone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop removed successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerPhone = _authService.currentUser?.phone ?? '';

    return ValueListenableBuilder<List<Shop>>(
      valueListenable: _databaseService.shopsNotifier,
      builder: (context, shops, child) {
        final myShops = _databaseService.getShopsByOwner(ownerPhone);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text(
              'My Shops',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                tooltip: 'Add Shop',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEditShopScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: myShops.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        const Text(
                          'No shops found in your portfolio',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap the button below to register your store and publish its live hours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddEditShopScreen()),
                            );
                          },
                          icon: const Icon(Icons.add_business_rounded, size: 18),
                          label: const Text('Add Shop Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myShops.length,
                  itemBuilder: (context, index) {
                    final shop = myShops[index];
                    final status = shop.getStatus();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: shop.isTemporarilyClosed
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFE2E8F0),
                          width: shop.isTemporarilyClosed ? 1.5 : 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Icon, Name, Category & Delete Menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(shop.categoryIcon, color: const Color(0xFF0F172A), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${shop.category} • ${shop.city}, ${shop.state}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddEditShopScreen(existingShop: shop),
                                        ),
                                      );
                                    } else if (val == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ShopDetailsScreen(shop: shop),
                                        ),
                                      );
                                    } else if (val == 'delete') {
                                      _handleDeleteShop(shop);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit Information'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Customer View'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                          SizedBox(width: 8),
                                          Text('Delete Shop', style: TextStyle(color: Color(0xFFDC2626))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Address & PIN
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${shop.address}, ${shop.city} - ${shop.pincode}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Today's opening hours
                            Builder(
                              builder: (context) {
                                final todaySchedule = shop.weeklySchedule[DateTime.now().weekday];
                                final todayHours = todaySchedule != null ? todaySchedule.formattedHours : 'Closed';
                                return Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "Today's Hours: $todayHours",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 10),

                            // Current Status Badge & Timing Info
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status.backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: status.borderColor),
                                  ),
                                  child: Text(
                                    status.statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: status.statusColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status.detailText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: status.statusColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Action Buttons: Edit and Temporarily Close / Reopen Shop
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddEditShopScreen(existingShop: shop),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Edit'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: shop.isTemporarilyClosed
                                      ? ElevatedButton.icon(
                                          onPressed: () => _handleToggleTemporaryClosure(shop),
                                          icon: const Icon(Icons.replay_rounded, size: 16),
                                          label: const Text('Reopen Shop'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => _handleToggleTemporaryClosure(shop),
                                          icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                                          label: const Text('Temporarily Close Shop'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD97706),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
