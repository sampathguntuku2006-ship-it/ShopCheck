import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/shop_card.dart';

/// Screen displaying a customer's saved favorite shops with live status and distance.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  double _customerLat = LocationService.defaultIndiaLat;
  double _customerLng = LocationService.defaultIndiaLng;

  @override
  void initState() {
    super.initState();
    _initCustomerLocation();
  }

  void _initCustomerLocation() {
    final pos = LocationService().currentPosition;
    if (pos != null) {
      _customerLat = pos.latitude;
      _customerLng = pos.longitude;
    }
  }

  List<Shop> _getFavoriteShopsWithDistance() {
    final userPhone = AuthService().currentUser?.phone ?? 'guest_customer';
    final favShops = DatabaseService().getFavoriteShops(userPhone);

    return favShops.map((shop) {
      final distKm = LocationService.calculateDistanceKm(
        _customerLat,
        _customerLng,
        shop.latitude,
        shop.longitude,
      );
      final formattedDist = '${LocationService.formatDistance(distKm)} away';
      return shop.copyWith(distance: formattedDist);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Favorite Shops',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Your saved shops & live hours',
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
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          DatabaseService().favoritesRevisionNotifier,
          DatabaseService().shopsNotifier,
        ]),
        builder: (context, _) {
          final favoriteShops = _getFavoriteShopsWithDistance();

          if (favoriteShops.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFECACA), width: 2),
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 38,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Favorite Shops Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap the heart icon on any shop details page to save your favorite shops here for quick access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              // Count Header
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  children: [
                    Text(
                      'Saved Shops (${favoriteShops.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // List of favorite shops
              ...favoriteShops.map((shop) => ShopCard(shop: shop)),
            ],
          );
        },
      ),
    );
  }
}
