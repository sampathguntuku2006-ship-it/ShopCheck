import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcheck/main.dart';
import 'package:shopcheck/screens/home_screen.dart';
import 'package:shopcheck/screens/shop_details_screen.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';
import 'package:shopcheck/services/location_service.dart';
import 'package:shopcheck/widgets/shop_card.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AuthService().resetForTesting(enablePersistence: false);
    await AuthService().init(enablePersistence: false);
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
    LocationService().resetForTesting();
  });

  tearDown(() {
    LocationService().resetForTesting();
  });

  testWidgets('Nearby Shops defaults to India coordinates when GPS is not granted', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify presence of India Default Location banner
    expect(find.textContaining('India Default Location'), findsOneWidget);
    expect(find.textContaining('20.5937'), findsOneWidget);
    expect(find.textContaining('78.9629'), findsOneWidget);

    // Verify distance is formatted with 'away' on shop cards
    expect(find.textContaining('away'), findsWidgets);
  });

  testWidgets('Nearby Shops dynamically uses GPS coordinates when available', (tester) async {
    // Set a mock GPS location in Bengaluru near Indiranagar
    LocationService().setMockPositionForTesting(12.9716, 77.5946);

    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify GPS Active banner is displayed with coordinates
    expect(find.textContaining('GPS active'), findsOneWidget);
    expect(find.textContaining('12.9716'), findsOneWidget);
    expect(find.textContaining('77.5946'), findsOneWidget);

    // In Bengaluru, Third Wave Coffee Roasters (Bengaluru) should be much closer than Karachi Bakery (Hyderabad)
    final shopCards = tester.widgetList<ShopCard>(find.byType(ShopCard)).toList();
    expect(shopCards.isNotEmpty, isTrue);

    // The first shop nearest to Bengaluru should be Third Wave Coffee Roasters
    expect(shopCards.first.shop.name, equals('Third Wave Coffee Roasters'));
    expect(shopCards.first.shop.distance, contains('away'));
  });

  testWidgets('Shops are sorted from nearest to farthest', (tester) async {
    // Set GPS in Hyderabad center
    LocationService().setMockPositionForTesting(17.3850, 78.4867);

    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    final shopCards = tester.widgetList<ShopCard>(find.byType(ShopCard)).toList();
    expect(shopCards.length, greaterThanOrEqualTo(2));

    // In Hyderabad, Hyderabad shops (Sri Krishna & Karachi Bakery) should appear before Bengaluru or Delhi shops
    final firstShop = shopCards[0].shop;
    final secondShop = shopCards[1].shop;

    expect(firstShop.city, equals('Hyderabad'));
    expect(secondShop.city, equals('Hyderabad'));

    // Distance on first shop should be small (e.g. within 10 km)
    expect(firstShop.distance, contains('away'));
  });

  testWidgets('Shop Card displays Name, Category, Status, and Distance', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify shop cards show category, status, and distance
    final firstCard = find.byType(ShopCard).first;
    expect(firstCard, findsOneWidget);

    final shop = tester.widget<ShopCard>(firstCard).shop;
    expect(shop.name.isNotEmpty, isTrue);
    expect(shop.category.isNotEmpty, isTrue);
    expect(shop.distance.contains('away'), isTrue);

    // Check OPEN or CLOSED badge is displayed
    final status = shop.getStatus();
    expect(find.text(status.statusText), findsWidgets);
  });

  testWidgets('Tapping a nearby shop opens the Shop Details screen with distance', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    final firstShopCard = find.byType(ShopCard).first;
    final shop = tester.widget<ShopCard>(firstShopCard).shop;

    // Tap the shop card
    await tester.tap(firstShopCard);
    await tester.pumpAndSettle();

    // Should now be on ShopDetailsScreen
    expect(find.byType(ShopDetailsScreen), findsOneWidget);
    expect(find.text(shop.name), findsWidgets);
    expect(find.text('${shop.address}, ${shop.city}, ${shop.state} - ${shop.pincode}'), findsOneWidget);
    expect(find.text(shop.phone), findsOneWidget);
    expect(find.text(shop.distance), findsWidgets);
  });

  testWidgets('View All Nearby Shops button clears search filter and restores all shops', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Search for a specific store "Bakery"
    await tester.enterText(find.byType(TextField), 'Bakery');
    await tester.pumpAndSettle();

    // Should see "Search Results (1)" and "View All Nearby Shops"
    expect(find.text('Search Results (1)'), findsOneWidget);
    expect(find.text('View All Nearby Shops'), findsOneWidget);

    // Tap "View All Nearby Shops"
    await tester.tap(find.text('View All Nearby Shops'));
    await tester.pumpAndSettle();

    // Should be back to "Nearby Shops (8)"
    expect(find.text('Nearby Shops (8)'), findsOneWidget);
    expect(find.text('Karachi Bakery & Confectionery'), findsOneWidget);
    expect(find.text('Sri Krishna Supermarket'), findsOneWidget);
  });
}
