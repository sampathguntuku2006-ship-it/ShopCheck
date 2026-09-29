import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/models/shop.dart';
import 'package:shopcheck/models/user.dart';
import 'package:shopcheck/screens/favorites_screen.dart';
import 'package:shopcheck/screens/home_screen.dart';
import 'package:shopcheck/screens/shop_details_screen.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';
import 'package:shopcheck/services/location_service.dart';
import 'package:shopcheck/widgets/shop_card.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().resetForTesting(enablePersistence: false);
    await AuthService().init(enablePersistence: false);
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
    LocationService().resetForTesting();
  });

  tearDown(() {
    LocationService().resetForTesting();
    DatabaseService().resetForTesting();
  });

  final testShop1 = Shop(
    id: 'test_fav_shop_1',
    ownerId: 'owner_1',
    name: 'Karachi Bakery Hyderabad',
    category: 'Grocery',
    categoryIcon: Icons.shopping_basket_rounded,
    address: 'Mozamjahi Market',
    city: 'Hyderabad',
    state: 'Telangana',
    pincode: '500001',
    latitude: 17.3850,
    longitude: 78.4867,
    phone: '+91 98490 11111',
    distance: '1.2 km away',
    description: 'Famous bakery and confectionery.',
    weeklySchedule: {
      1: const DaySchedule.allDay(),
    },
  );

  final testShop2 = Shop(
    id: 'test_fav_shop_2',
    ownerId: 'owner_2',
    name: 'MedPlus Pharmacy',
    category: 'Pharmacy',
    categoryIcon: Icons.local_pharmacy_rounded,
    address: 'Banjara Hills',
    city: 'Hyderabad',
    state: 'Telangana',
    pincode: '500034',
    latitude: 17.4156,
    longitude: 78.4347,
    phone: '+91 98490 22222',
    distance: '3.5 km away',
    description: 'Medicines and healthcare products.',
    weeklySchedule: {
      1: const DaySchedule.closed(),
    },
  );

  testWidgets('Customer can add and remove shop from Favorites via heart button', (tester) async {
    // Authenticate as a customer
    final loginRes = await AuthService().login(phone: '555-123-4567', password: 'Password123');
    expect(loginRes.isSuccess, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: testShop1),
      ),
    );
    await tester.pumpAndSettle();

    // Verify favorite heart icon is initially border (not favorited)
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(DatabaseService().isFavorite(testShop1.id, '5551234567'), isFalse);

    // Tap the heart icon to favorite
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SnackBar appears and heart becomes filled
    expect(find.textContaining('added to Favorites'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(DatabaseService().isFavorite(testShop1.id, '5551234567'), isTrue);

    // Tap again to unfavorite
    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SnackBar appears and heart returns to border
    expect(find.textContaining('removed from Favorites'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(DatabaseService().isFavorite(testShop1.id, '5551234567'), isFalse);
  });

  testWidgets('Shop owners cannot favorite shops', (tester) async {
    // Authenticate as a shop owner
    final loginRes = await AuthService().login(phone: '555-987-6543', password: 'OwnerPass123');
    expect(loginRes.isSuccess, isTrue);
    expect(AuthService().currentUser?.role, equals(UserRole.shopOwner));

    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: testShop1),
      ),
    );
    await tester.pumpAndSettle();

    // Heart icon must NOT be shown for shop owners
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('FavoritesScreen displays saved shops with Name, Category, Status, Distance', (tester) async {
    // Authenticate customer and add a favorite shop
    await AuthService().login(phone: '555-123-4567', password: 'Password123');
    await DatabaseService().saveShop(testShop1, 'system_admin');
    await DatabaseService().addFavorite(testShop1.id, '5551234567');

    await tester.pumpWidget(
      const MaterialApp(
        home: FavoritesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and presence of saved shop
    expect(find.text('Favorite Shops'), findsOneWidget);
    expect(find.text('Saved Shops (1)'), findsOneWidget);
    expect(find.text(testShop1.name), findsOneWidget);
    expect(find.text(testShop1.category), findsOneWidget);

    // Verify status badge
    final status = testShop1.getStatus();
    expect(find.text(status.statusText), findsOneWidget);

    // Verify distance is shown
    expect(find.textContaining('away'), findsWidgets);
  });

  testWidgets('Tapping a favorite shop card opens ShopDetailsScreen', (tester) async {
    await AuthService().login(phone: '555-123-4567', password: 'Password123');
    await DatabaseService().saveShop(testShop1, 'system_admin');
    await DatabaseService().addFavorite(testShop1.id, '5551234567');

    await tester.pumpWidget(
      const MaterialApp(
        home: FavoritesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on the shop card
    await tester.tap(find.byType(ShopCard));
    await tester.pumpAndSettle();

    // Should now be on ShopDetailsScreen
    expect(find.byType(ShopDetailsScreen), findsOneWidget);
    expect(find.text(testShop1.name), findsWidgets);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget); // Is favorited
  });

  testWidgets('Each customer favorites are separate', (tester) async {
    await DatabaseService().saveShop(testShop1, 'system_admin');
    await DatabaseService().saveShop(testShop2, 'system_admin');

    // Customer A favorites shop 1
    const customerA = '5551234567';
    await DatabaseService().addFavorite(testShop1.id, customerA);

    // Customer B favorites shop 2
    const customerB = '5559990000';
    await DatabaseService().addFavorite(testShop2.id, customerB);

    // Verify customer A has only shop 1
    expect(DatabaseService().isFavorite(testShop1.id, customerA), isTrue);
    expect(DatabaseService().isFavorite(testShop2.id, customerA), isFalse);

    // Verify customer B has only shop 2
    expect(DatabaseService().isFavorite(testShop1.id, customerB), isFalse);
    expect(DatabaseService().isFavorite(testShop2.id, customerB), isTrue);
  });

  testWidgets('Favorites persist after closing and reopening the app', (tester) async {
    // Enable persistent SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final db1 = DatabaseService();
    await db1.init(enablePersistence: true);
    await db1.saveShop(testShop1, 'system_admin');

    const customerPhone = '5551234567';
    await db1.addFavorite(testShop1.id, customerPhone);
    expect(db1.isFavorite(testShop1.id, customerPhone), isTrue);

    // Simulate closing app and reopening with fresh service instance
    db1.resetForTesting();
    expect(db1.isFavorite(testShop1.id, customerPhone), isFalse);

    // Reinitialize app from persistent storage
    await db1.init(enablePersistence: true);
    expect(db1.isFavorite(testShop1.id, customerPhone), isTrue);
    expect(db1.getFavoriteShops(customerPhone).first.id, equals(testShop1.id));
  });

  testWidgets('HomeScreen Favorites status chip filters saved shops', (tester) async {
    await AuthService().login(phone: '555-123-4567', password: 'Password123');
    await DatabaseService().saveShop(testShop1, 'system_admin');
    await DatabaseService().addFavorite(testShop1.id, '5551234567');

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Favorites filter chip is present
    expect(find.text('Favorites'), findsOneWidget);

    // Tap Favorites chip
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    // Should see header "Favorite Shops (1)" and testShop1
    expect(find.text('Favorite Shops (1)'), findsOneWidget);
    expect(find.text(testShop1.name), findsOneWidget);
  });
}
