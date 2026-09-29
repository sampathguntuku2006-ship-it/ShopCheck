import 'package:flutter/material.dart';
import '../data/sample_shops.dart';
import '../models/shop.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/shop_card.dart';
import 'chat_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All Shops'; // 'All Shops', 'Open Now', 'Closed'
  String _selectedCategory = 'All';

  static const List<({String name, IconData icon})> _categoryOptions = [
    (name: 'All', icon: Icons.storefront_rounded),
    (name: 'Grocery', icon: Icons.shopping_basket_rounded),
    (name: 'Pharmacy', icon: Icons.local_pharmacy_rounded),
    (name: 'Restaurant', icon: Icons.restaurant_rounded),
    (name: 'Clothing', icon: Icons.checkroom_rounded),
    (name: 'Electronics', icon: Icons.devices_rounded),
    (name: 'Hardware', icon: Icons.build_rounded),
    (name: 'Other', icon: Icons.category_rounded),
  ];

  // Customer location state (defaults to India center)
  double _customerLat = LocationService.defaultIndiaLat;
  double _customerLng = LocationService.defaultIndiaLng;
  bool _isUsingGps = false;

  @override
  void initState() {
    super.initState();
    _initCustomerLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Acquires user GPS location, or gracefully falls back to India default coordinates.
  Future<void> _initCustomerLocation({bool requestIfNotGranted = true}) async {
    // If LocationService already has cached or mock position, use it directly
    if (LocationService().currentPosition != null) {
      if (mounted) {
        setState(() {
          _customerLat = LocationService().currentPosition!.latitude;
          _customerLng = LocationService().currentPosition!.longitude;
          _isUsingGps = true;
        });
      }
      return;
    }

    try {
      final pos = await LocationService().getCurrentLocation(
        requestIfNotGranted: requestIfNotGranted,
      );

      if (!mounted) return;

      if (pos != null) {
        setState(() {
          _customerLat = pos.latitude;
          _customerLng = pos.longitude;
          _isUsingGps = true;
        });
      } else {
        setState(() {
          _customerLat = LocationService.defaultIndiaLat;
          _customerLng = LocationService.defaultIndiaLng;
          _isUsingGps = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customerLat = LocationService.defaultIndiaLat;
        _customerLng = LocationService.defaultIndiaLng;
        _isUsingGps = false;
      });
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      (_selectedStatus != 'All Shops' && _selectedStatus != 'All') ||
      _selectedCategory != 'All';

  void _viewAllNearbyShops() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedStatus = 'All Shops';
      _selectedCategory = 'All';
    });
  }

  bool _matchesSearch(Shop shop, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return shop.name.toLowerCase().contains(q) ||
        shop.category.toLowerCase().contains(q) ||
        shop.city.toLowerCase().contains(q) ||
        shop.address.toLowerCase().contains(q) ||
        shop.state.toLowerCase().contains(q);
  }

  bool _matchesCategory(Shop shop, String selectedCategory) {
    if (selectedCategory == 'All') return true;

    final cat = shop.category.toLowerCase();
    switch (selectedCategory) {
      case 'Grocery':
        return cat.contains('grocery') || cat.contains('supermarket') || cat.contains('bakery');
      case 'Pharmacy':
        return cat.contains('pharmacy') || cat.contains('wellness') || cat.contains('medical');
      case 'Restaurant':
        return cat.contains('restaurant') || cat.contains('dining') || cat.contains('cafe') || cat.contains('coffee');
      case 'Clothing':
        return cat.contains('clothing') || cat.contains('fashion') || cat.contains('apparel');
      case 'Electronics':
        return cat.contains('electronics') || cat.contains('repair') || cat.contains('gadget');
      case 'Hardware':
        return cat.contains('hardware') || cat.contains('tool');
      case 'Other':
        final isGrocery = cat.contains('grocery') || cat.contains('supermarket') || cat.contains('bakery');
        final isPharmacy = cat.contains('pharmacy') || cat.contains('wellness') || cat.contains('medical');
        final isRestaurant = cat.contains('restaurant') || cat.contains('dining') || cat.contains('cafe') || cat.contains('coffee');
        final isClothing = cat.contains('clothing') || cat.contains('fashion') || cat.contains('apparel');
        final isElectronics = cat.contains('electronics') || cat.contains('repair') || cat.contains('gadget');
        final isHardware = cat.contains('hardware') || cat.contains('tool');
        return !isGrocery && !isPharmacy && !isRestaurant && !isClothing && !isElectronics && !isHardware;
      default:
        return cat.contains(selectedCategory.toLowerCase());
    }
  }

  List<Shop> get _filteredShops {
    final all = DatabaseService().getAllShops().isNotEmpty
        ? DatabaseService().getAllShops()
        : sampleShops;

    // 1. Calculate Haversine distance from customer location and format as "X km away"
    final shopsWithDist = all.map((shop) {
      final distKm = LocationService.calculateDistanceKm(
        _customerLat,
        _customerLng,
        shop.latitude,
        shop.longitude,
      );
      final formattedDist = '${LocationService.formatDistance(distKm)} away';
      return (
        shop: shop.copyWith(distance: formattedDist),
        distanceKm: distKm,
      );
    }).toList();

    // 2. Sort shops dynamically from nearest to farthest
    shopsWithDist.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // 3. Filter by search query (Name, Category, City, Address, State), Status tab, and Category filter
    return shopsWithDist.map((item) => item.shop).where((shop) {
      // 3a. Search matching
      if (!_matchesSearch(shop, _searchQuery)) return false;

      // 3b. Status filter matching
      if (_selectedStatus == 'Open Now' || _selectedStatus == 'Open') {
        if (!shop.getStatus().isOpen) return false;
      } else if (_selectedStatus == 'Closed') {
        if (shop.getStatus().isOpen) return false;
      } else if (_selectedStatus == 'Favorites') {
        final userPhone = AuthService().currentUser?.phone ?? 'guest_customer';
        if (!DatabaseService().isFavorite(shop.id, userPhone)) return false;
      }

      // 3c. Category matching
      if (!_matchesCategory(shop, _selectedCategory)) return false;

      return true;
    }).toList();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DatabaseService().favoritesRevisionNotifier,
      builder: (context, _) {
        final allShops = DatabaseService().getAllShops().isNotEmpty
            ? DatabaseService().getAllShops()
            : sampleShops;
        final openCount = allShops.where((s) => s.getStatus().isOpen).length;
        final closedCount = allShops.length - openCount;
        final userPhone = AuthService().currentUser?.phone ?? 'guest_customer';
        final favCount = DatabaseService().getFavorites(userPhone).length;
        final isCustomer = AuthService().currentUser?.role != UserRole.shopOwner;
        final filtered = _filteredShops;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ShopCheck',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Check live store status before you go',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (isCustomer)
                IconButton(
                  icon: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 20),
                  tooltip: 'Favorite Shops',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 20),
                tooltip: 'Log Out',
                onPressed: () => _confirmLogout(),
              ),
              const AppMenuButton(),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter Header Container
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
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
                    // Customer Quick Actions
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickActionChip(
                            label: 'Search Shops',
                            icon: Icons.search_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SearchScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionChip(
                            label: 'Nearby Shops',
                            icon: Icons.near_me_rounded,
                            onTap: _viewAllNearbyShops,
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionChip(
                            label: 'Open Now',
                            icon: Icons.check_circle_outline_rounded,
                            onTap: () {
                              setState(() {
                                _selectedStatus = 'Open Now';
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionChip(
                            label: 'Map',
                            icon: Icons.map_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MapScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionChip(
                            label: 'Saved',
                            icon: Icons.favorite_outline_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search shops by name...',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: Color(0xFF64748B),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Status Filter Chips (All Shops, Open Now, Closed, Favorites) with live count pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All Shops', '${allShops.length}', null),
                          const SizedBox(width: 8),
                          _buildFilterChip('Open Now', '$openCount', const Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          _buildFilterChip('Closed', '$closedCount', const Color(0xFFDC2626)),
                          if (isCustomer) ...[
                            const SizedBox(width: 8),
                            _buildFilterChip('Favorites', '$favCount', const Color(0xFFEF4444)),
                          ],
                        ],
                      ),
                    ),
                const SizedBox(height: 10),
                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categoryOptions.map((cat) {
                      final isSelected = _selectedCategory == cat.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCategoryChip(cat.name, cat.icon, isSelected),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // Customer Location Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isUsingGps ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isUsingGps ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isUsingGps ? Icons.my_location_rounded : Icons.location_on_outlined,
                        size: 15,
                        color: _isUsingGps ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isUsingGps
                              ? 'GPS active (${_customerLat.toStringAsFixed(4)}°, ${_customerLng.toStringAsFixed(4)}°)'
                              : 'India Default Location (${LocationService.defaultIndiaLat.toStringAsFixed(4)}°, ${LocationService.defaultIndiaLng.toStringAsFixed(4)}°)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isUsingGps ? const Color(0xFF15803D) : const Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _initCustomerLocation(requestIfNotGranted: true),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Tooltip(
                            message: 'Refresh Location',
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 15,
                              color: _isUsingGps ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Shop Count Header & View All Nearby Option
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Search Results (${filtered.length})'
                      : (_selectedStatus == 'Favorites'
                          ? 'Favorite Shops (${filtered.length})'
                          : 'Nearby Shops (${filtered.length})'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters)
                  InkWell(
                    onTap: _viewAllNearbyShops,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: Color(0xFF16A34A),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View All Nearby Shops',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Nearest first',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // List of Shops
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    child: Column(
                      children: filtered.map((shop) => ShopCard(shop: shop)).toList(),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_screen_ai_fab',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        },
        backgroundColor: const Color(0xFF16A34A),
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

  Widget _buildQuickActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF16A34A)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String count, Color? accentColor) {
    final isSelected = _selectedStatus == label;

    return InkWell(
      onTap: () {
        setState(() {
          if (label == 'All Shops') {
            _selectedStatus = 'All Shops';
            _selectedCategory = 'All';
          } else {
            _selectedStatus = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (accentColor?.withValues(alpha: 0.12) ?? const Color(0xFF0F172A))
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (accentColor ?? const Color(0xFF0F172A))
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (accentColor ?? Colors.white)
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (accentColor ?? Colors.white.withValues(alpha: 0.2))
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String messageTitle;
    String messageSubtitle;

    if (_searchQuery.isNotEmpty && _selectedCategory != 'All') {
      messageTitle = 'No shops found for "$_searchQuery" in $_selectedCategory';
      messageSubtitle = 'Try clearing the category filter or searching with a different term.';
    } else if (_searchQuery.isNotEmpty) {
      messageTitle = 'No shops found for "$_searchQuery"';
      messageSubtitle = 'Try searching by shop name, category, or city (e.g. Hyderabad, Bengaluru, Mumbai).';
    } else if (_selectedCategory != 'All' && (_selectedStatus == 'Open Now' || _selectedStatus == 'Open')) {
      messageTitle = 'No $_selectedCategory shops currently open';
      messageSubtitle = 'Check back during operating hours or view all shops.';
    } else if (_selectedCategory != 'All') {
      messageTitle = 'No shops found in $_selectedCategory';
      messageSubtitle = 'Try selecting another category or view all shops.';
    } else if (_selectedStatus == 'Favorites') {
      messageTitle = 'No favorite shops saved yet';
      messageSubtitle = 'Tap the heart icon on any shop details page to add it to your favorites.';
    } else {
      messageTitle = 'No shops match the selected filter';
      messageSubtitle = 'Try clearing your filters to see all nearby shops.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              messageTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              messageSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            if (_hasActiveFilters)
              ElevatedButton.icon(
                onPressed: _viewAllNearbyShops,
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: const Text('All Shops'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
