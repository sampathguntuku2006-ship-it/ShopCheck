import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'shop_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  double _centerLat = LocationService.defaultIndiaLat;
  double _centerLng = LocationService.defaultIndiaLng;
  double _zoomLevel = 1.0; // 1.0 = country level, up to 4.0 = city level

  String _selectedCity = 'All India';
  Shop? _selectedShop;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _databaseService.shopsNotifier.addListener(_onShopsChanged);
    // Auto-select first shop if available
    final all = _databaseService.getAllShops();
    if (all.isNotEmpty) {
      _selectedShop = all.first;
    }
  }

  void _onShopsChanged() {
    if (!mounted) return;
    setState(() {
      if (_selectedShop != null) {
        final updated = _databaseService.getShopById(_selectedShop!.id);
        _selectedShop = updated ?? (_databaseService.getAllShops().isNotEmpty ? _databaseService.getAllShops().first : null);
      }
    });
  }

  @override
  void dispose() {
    _databaseService.shopsNotifier.removeListener(_onShopsChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestUserLocation() async {
    final result =
        await _locationService.requestLocationDetailed(requestIfNotGranted: true);
    if (!mounted) return;

    final pos = result.position;
    if (pos != null) {
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        _zoomLevel = 3.0;
        _selectedCity = 'My Location';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _jumpToCity(String cityName) {
    setState(() {
      _selectedCity = cityName;
      if (cityName == 'All India') {
        _centerLat = LocationService.defaultIndiaLat;
        _centerLng = LocationService.defaultIndiaLng;
        _zoomLevel = 1.0;
      } else if (LocationService.indianCities.containsKey(cityName)) {
        final data = LocationService.indianCities[cityName]!;
        _centerLat = data.lat;
        _centerLng = data.lng;
        _zoomLevel = 2.5;

        // Auto-select a shop in this city if found
        final cityShops = _databaseService
            .getAllShops()
            .where((s) => s.city.toLowerCase() == cityName.toLowerCase())
            .toList();
        if (cityShops.isNotEmpty) {
          _selectedShop = cityShops.first;
        }
      }
    });
  }

  List<Shop> get _displayedShops {
    return _databaseService.getAllShops().where((shop) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = shop.name.toLowerCase().contains(query) ||
            shop.category.toLowerCase().contains(query) ||
            shop.city.toLowerCase().contains(query) ||
            shop.address.toLowerCase().contains(query);
        if (!matches) return false;
      }

      if (_selectedCity != 'All India' && _selectedCity != 'My Location') {
        return shop.city.toLowerCase() == _selectedCity.toLowerCase();
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shops = _displayedShops;
    final currentPos = _locationService.currentPosition;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Stack(
          children: [
            // Map Canvas & Markers
            Positioned.fill(
              child: GestureDetector(
                onScaleUpdate: (details) {
                  setState(() {
                    _zoomLevel = (_zoomLevel * details.scale).clamp(0.8, 5.0);
                  });
                },
                child: CustomPaint(
                  painter: _IndiaMapPainter(
                    centerLat: _centerLat,
                    centerLng: _centerLng,
                    zoomLevel: _zoomLevel,
                    userPosition: currentPos,
                  ),
                  child: Stack(
                    children: [
                      // Shop Markers plotted onto the map
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: shops.map((shop) {
                              final offset = _latLngToScreen(
                                shop.latitude,
                                shop.longitude,
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );

                              // Only render if within visible screen bounds
                              if (offset.dx < -50 ||
                                  offset.dx > constraints.maxWidth + 50 ||
                                  offset.dy < -50 ||
                                  offset.dy > constraints.maxHeight + 50) {
                                return const SizedBox.shrink();
                              }

                              final isSelected = _selectedShop?.id == shop.id;
                              final status = shop.getStatus();

                              return Positioned(
                                left: offset.dx - 22,
                                top: offset.dy - 44,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedShop = shop;
                                    });
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Marker Bubble
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status.statusColor,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: isSelected ? 8 : 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: Colors.white,
                                            width: isSelected ? 2.5 : 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              shop.categoryIcon,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              shop.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isSelected ? 11 : 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Marker Pin Tip
                                      CustomPaint(
                                        size: const Size(10, 8),
                                        painter: _TrianglePainter(status.statusColor),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Overlay: Search Bar & City Selector
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search shops or Indian cities...',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF16A34A)),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // City Quick-Jump Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCityChip('All India'),
                        ...LocationService.indianCities.keys.map((c) => _buildCityChip(c)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Map Controls (Zoom In, Zoom Out, GPS button)
            Positioned(
              right: 16,
              bottom: _selectedShop != null ? 220 : 24,
              child: Column(
                children: [
                  _buildFloatingAction(
                    icon: Icons.my_location_rounded,
                    tooltip: 'My Location',
                    color: const Color(0xFF2563EB),
                    onTap: _requestUserLocation,
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingAction(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom In',
                    color: const Color(0xFF0F172A),
                    onTap: () {
                      setState(() {
                        _zoomLevel = (_zoomLevel * 1.3).clamp(0.8, 5.0);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingAction(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom Out',
                    color: const Color(0xFF0F172A),
                    onTap: () {
                      setState(() {
                        _zoomLevel = (_zoomLevel / 1.3).clamp(0.8, 5.0);
                      });
                    },
                  ),
                ],
              ),
            ),

            // Bottom Selected Shop Card
            if (_selectedShop != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildSelectedShopCard(_selectedShop!),
              ),
          ],
        ),
      ),
    );
  }

  Offset _latLngToScreen(double lat, double lng, double width, double height) {
    // Mercator-like normalized mapping around India
    // India bounds roughly Lat 8 to 36, Lng 68 to 97
    final latDelta = (lat - _centerLat);
    final lngDelta = (lng - _centerLng);

    final scale = (width / 35) * _zoomLevel;
    final screenX = (width / 2) + (lngDelta * scale);
    final screenY = (height / 2) - (latDelta * scale * 1.1);

    return Offset(screenX, screenY);
  }

  Widget _buildCityChip(String cityName) {
    final isSelected = _selectedCity == cityName;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(cityName),
        selected: isSelected,
        onSelected: (_) => _jumpToCity(cityName),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF16A34A),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF1E293B),
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedShopCard(Shop shop) {
    final status = shop.getStatus();

    // Compute live distance from user if location is available
    String distanceStr = shop.distance;
    final userPos = _locationService.currentPosition;
    if (userPos != null) {
      final km = LocationService.calculateDistanceKm(
        userPos.latitude,
        userPos.longitude,
        shop.latitude,
        shop.longitude,
      );
      distanceStr = LocationService.formatDistance(km);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon Avatar
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shop.category} • ${shop.city}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Close Card Button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () => setState(() => _selectedShop = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Status & Details Row
          Row(
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: status.borderColor),
                ),
                child: Text(
                  status.statusText,
                  style: TextStyle(
                    color: status.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
              // Distance tag
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 3),
                  Text(
                    distanceStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // "View Shop" Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShopDetailsScreen(shop: shop),
                  ),
                );
              },
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text(
                'View Shop',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom map painter rendering India regional guides, grid, and user GPS
class _IndiaMapPainter extends CustomPainter {
  final double centerLat;
  final double centerLng;
  final double zoomLevel;
  final dynamic userPosition;

  _IndiaMapPainter({
    required this.centerLat,
    required this.centerLng,
    required this.zoomLevel,
    this.userPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Map background styling
    final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle map grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    const gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw India subcontinent landmass polygon guide
    final landPaint = Paint()..color = const Color(0xFFF8FAFC);
    final borderPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Approximate India regional polygon coordinates
    final indiaCoords = [
      (lat: 35.5, lng: 74.5), // North Kashmir
      (lat: 32.5, lng: 78.5), // Ladakh
      (lat: 28.5, lng: 80.5), // Uttarakhand / UP
      (lat: 27.0, lng: 88.5), // Sikkim
      (lat: 28.0, lng: 96.0), // Arunachal
      (lat: 24.5, lng: 93.5), // Manipur
      (lat: 22.0, lng: 89.0), // Bengal delta
      (lat: 19.5, lng: 85.5), // Odisha
      (lat: 13.0, lng: 80.3), // Chennai / East Coast
      (lat: 8.1, lng: 77.5),  // Kanyakumari (South tip)
      (lat: 15.0, lng: 73.8), // Goa
      (lat: 19.0, lng: 72.8), // Mumbai / Konkan
      (lat: 23.0, lng: 68.5), // Gujarat / Kutch
      (lat: 27.5, lng: 71.0), // Rajasthan border
      (lat: 31.5, lng: 74.8), // Punjab border
    ];

    final path = Path();
    bool first = true;
    for (final coord in indiaCoords) {
      final offset = _toScreen(coord.lat, coord.lng, size.width, size.height);
      if (first) {
        path.moveTo(offset.dx, offset.dy);
        first = false;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    path.close();

    canvas.drawPath(path, landPaint);
    canvas.drawPath(path, borderPaint);

    // User GPS indicator if detected
    if (userPosition != null) {
      final userOffset = _toScreen(
        userPosition.latitude as double,
        userPosition.longitude as double,
        size.width,
        size.height,
      );

      final gpsPulsePaint = Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.25);
      final gpsDotPaint = Paint()..color = const Color(0xFF2563EB);
      final gpsInnerPaint = Paint()..color = Colors.white;

      canvas.drawCircle(userOffset, 16 * zoomLevel.clamp(0.8, 2.0), gpsPulsePaint);
      canvas.drawCircle(userOffset, 7, gpsDotPaint);
      canvas.drawCircle(userOffset, 3, gpsInnerPaint);
    }
  }

  Offset _toScreen(double lat, double lng, double width, double height) {
    final latDelta = (lat - centerLat);
    final lngDelta = (lng - centerLng);
    final scale = (width / 35) * zoomLevel;
    final screenX = (width / 2) + (lngDelta * scale);
    final screenY = (height / 2) - (latDelta * scale * 1.1);
    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant _IndiaMapPainter oldDelegate) {
    return oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLng != centerLng ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.userPosition != userPosition;
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
