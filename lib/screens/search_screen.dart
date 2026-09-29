import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/shop_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _onlyOpenNow = false;
  bool _sortByNearby = false;
  String _selectedCategory = 'All';
  String _selectedCity = 'All';

  final List<String> _categories = [
    'All',
    'Grocery',
    'Pharmacy',
    'Bakery',
    'Electronics',
    'Coffee',
    'Restaurant',
    'Books',
    'Flowers',
  ];

  final List<String> _cities = [
    'All',
    'Hyderabad',
    'Bengaluru',
    'Mumbai',
    'Delhi',
    'Chennai',
    'Kolkata',
    'Pune',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Shop> get _filteredShops {
    final all = _databaseService.getAllShops();

    var results = all.where((shop) {
      // 1. Text Query (Search across name, category, city, address, pincode)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = shop.name.toLowerCase().contains(query) ||
            shop.category.toLowerCase().contains(query) ||
            shop.city.toLowerCase().contains(query) ||
            shop.address.toLowerCase().contains(query) ||
            shop.state.toLowerCase().contains(query) ||
            shop.pincode.contains(query);
        if (!matches) return false;
      }

      // 2. Open Now filter
      if (_onlyOpenNow) {
        if (!shop.getStatus().isOpen) return false;
      }

      // 3. Category filter
      if (_selectedCategory != 'All') {
        if (!shop.category.toLowerCase().contains(_selectedCategory.toLowerCase())) {
          return false;
        }
      }

      // 4. City filter
      if (_selectedCity != 'All') {
        if (shop.city.toLowerCase() != _selectedCity.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    // 5. Nearby sort
    if (_sortByNearby) {
      final userPos = _locationService.currentPosition;
      final refLat = userPos?.latitude ?? 17.3850;
      final refLng = userPos?.longitude ?? 78.4867;

      results.sort((a, b) {
        final distA = LocationService.calculateDistanceKm(refLat, refLng, a.latitude, a.longitude);
        final distB = LocationService.calculateDistanceKm(refLat, refLng, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredShops;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Search Shops',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Box
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
                      hintText: 'Search by name, category, city (e.g. Hyderabad)...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Toggle Chips (Open Now, Nearby)
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Open Now'),
                      selected: _onlyOpenNow,
                      onSelected: (val) => setState(() => _onlyOpenNow = val),
                      selectedColor: const Color(0xFFDCFCE7),
                      checkmarkColor: const Color(0xFF16A34A),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _onlyOpenNow ? const Color(0xFF16A34A) : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _onlyOpenNow ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Nearby'),
                      selected: _sortByNearby,
                      onSelected: (val) {
                        setState(() => _sortByNearby = val);
                        if (val && !_locationService.hasLocation) {
                          _locationService.getCurrentLocation();
                        }
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      checkmarkColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _sortByNearby ? const Color(0xFF2563EB) : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _sortByNearby ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Category & City Horizontal Selectors
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Category: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      ..._categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'City: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      ..._cities.map((city) {
                        final isSel = _selectedCity == city;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(city),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedCity = city),
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Count Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                Text(
                  'Found ${results.length} shops',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                if (_onlyOpenNow || _sortByNearby || _selectedCategory != 'All' || _selectedCity != 'All' || _searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _onlyOpenNow = false;
                        _sortByNearby = false;
                        _selectedCategory = 'All';
                        _selectedCity = 'All';
                      });
                    },
                    child: const Text(
                      'Clear Filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 14),
                          const Text(
                            'No shops matched your search criteria',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try selecting a different category or clearing your active filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      return ShopCard(shop: results[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
