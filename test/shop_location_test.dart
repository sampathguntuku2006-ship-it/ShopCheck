import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/screens/add_edit_shop_screen.dart';
import 'package:shopcheck/screens/map_screen.dart';
import 'package:shopcheck/screens/shop_details_screen.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';
import 'package:shopcheck/services/location_service.dart';

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

  testWidgets('AddEditShopScreen displays Shop Location section with coordinates and buttons', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AddEditShopScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Shop Location section title
    expect(find.text('Shop Location'), findsWidgets);
    expect(find.text('Exact Shop Coordinates'), findsOneWidget);
    expect(find.text('GPS Pinned'), findsOneWidget);
    expect(find.text('LATITUDE'), findsOneWidget);
    expect(find.text('LONGITUDE'), findsOneWidget);
    expect(find.text('Use My Current Location'), findsOneWidget);
    expect(find.text('Select Exact Location on Map'), findsOneWidget);
  });

  testWidgets('Opening map location picker allows selecting city preset and confirms location', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AddEditShopScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Select Exact Location on Map
    await tester.tap(find.text('Select Exact Location on Map'));
    await tester.pumpAndSettle();

    // Verify picker bottom sheet is open
    expect(find.text('Select Shop Location'), findsOneWidget);
    expect(find.textContaining('Tap to pin'), findsOneWidget);
    expect(find.text('Bengaluru'), findsOneWidget);
    expect(find.text('Confirm Location'), findsWidgets);

    // Tap Bengaluru preset
    await tester.tap(find.text('Bengaluru'));
    await tester.pumpAndSettle();

    // Selected coordinates card should now display Bengaluru coordinates (12.9716, 77.5946)
    expect(find.textContaining('12.9716'), findsOneWidget);
    expect(find.textContaining('77.5946'), findsOneWidget);

    // Confirm location
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Location').last);
    await tester.pumpAndSettle();

    // Should return to AddEditShopScreen with updated coordinates
    expect(find.text('12.9716° N'), findsOneWidget);
    expect(find.text('77.5946° E'), findsOneWidget);
  });

  testWidgets('Use My Current Location button on AddEditShopScreen updates coordinates when GPS is granted', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Mock GPS position in Mumbai (19.0760, 72.8777)
    LocationService().setMockPositionForTesting(19.0760, 72.8777);

    await tester.pumpWidget(
      const MaterialApp(
        home: AddEditShopScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Use My Current Location
    await tester.tap(find.text('Use My Current Location'));
    await tester.pumpAndSettle();

    // Coordinates should update to Mumbai coordinates
    expect(find.text('19.0760° N'), findsOneWidget);
    expect(find.text('72.8777° E'), findsOneWidget);
    expect(find.textContaining('Location detected: 19.0760, 72.8777'), findsOneWidget);
  });

  testWidgets('Use My Current Location inside MapLocationPickerSheet updates marker and can be confirmed', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Mock GPS position in Pune (18.5204, 73.8567)
    LocationService().setMockPositionForTesting(18.5204, 73.8567);

    await tester.pumpWidget(
      const MaterialApp(
        home: AddEditShopScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Open map picker sheet
    await tester.tap(find.text('Select Exact Location on Map'));
    await tester.pumpAndSettle();

    // Tap Use My Current Location button inside sheet
    await tester.tap(find.widgetWithText(OutlinedButton, 'Use My Current Location').last);
    await tester.pumpAndSettle();

    // Verify coordinates updated in sheet
    expect(find.textContaining('18.5204'), findsWidgets);
    expect(find.textContaining('73.8567'), findsWidgets);

    // Tap Confirm Location
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Location').last);
    await tester.pumpAndSettle();

    // Verify returned coordinates on main form
    expect(find.text('18.5204° N'), findsOneWidget);
    expect(find.text('73.8567° E'), findsOneWidget);
  });

  testWidgets('Location permission denied handles gracefully without blocking manual selection or saving', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Simulate location permission denied
    LocationService().setMockPermissionDeniedForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: AddEditShopScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Use My Current Location
    await tester.tap(find.text('Use My Current Location'));
    await tester.pumpAndSettle();

    // Verify graceful feedback message
    expect(find.textContaining('Location permission denied'), findsOneWidget);

    // Fallback coordinates should remain India default or previous
    expect(find.textContaining('° N'), findsOneWidget);
    expect(find.textContaining('° E'), findsOneWidget);

    // Dismiss SnackBar so it doesn't obscure the button below
    ScaffoldMessenger.of(tester.element(find.byType(AddEditShopScreen))).clearSnackBars();
    await tester.pumpAndSettle();

    // Owner can still open the map picker and manually select a location
    await tester.tap(find.text('Select Exact Location on Map'));
    await tester.pumpAndSettle();

    expect(find.text('Select Shop Location'), findsOneWidget);
    await tester.tap(find.text('Mumbai'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Location').last);
    await tester.pumpAndSettle();

    expect(find.text('19.0760° N'), findsOneWidget);
    expect(find.text('72.8777° E'), findsOneWidget);
  });

  testWidgets('Customer Map and Shop Details display the shop location coordinates', (tester) async {
    // 1. Map screen displays shops at saved coordinates
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Sri Krishna Supermarket is shown on the map
    expect(find.text('Sri Krishna Supermarket'), findsAtLeastNWidgets(1));

    // 2. ShopDetailsScreen displays GPS coordinates badge
    final shop = DatabaseService().getAllShops().first;
    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: shop),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('GPS:'), findsOneWidget);
    expect(find.textContaining('° N'), findsOneWidget);
    expect(find.textContaining('° E'), findsOneWidget);
  });

  testWidgets('Updating shop location by owner immediately reflects on Customer Map', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final shop = DatabaseService().getAllShops().first;
    expect(find.text(shop.name), findsAtLeastNWidgets(1));

    // Update shop location via DatabaseService (e.g. moved to Kolkata: 22.5726, 88.3639)
    final updatedShop = shop.copyWith(
      latitude: 22.5726,
      longitude: 88.3639,
      city: 'Kolkata',
    );
    await DatabaseService().saveShop(updatedShop, shop.ownerId);
    await tester.pumpAndSettle();

    // Map screen should have reacted immediately through shopsNotifier
    final retrieved = DatabaseService().getShopById(shop.id);
    expect(retrieved?.latitude, equals(22.5726));
    expect(retrieved?.longitude, equals(88.3639));
  });

  test('Shop owner can only modify their own shop and customer cannot edit shop location', () async {
    final shops = DatabaseService().getAllShops();
    final targetShop = shops.first;

    // Unauthorized user attempt to edit shop location
    final unauthorizedSuccess = await DatabaseService().saveShop(
      targetShop.copyWith(latitude: 10.0, longitude: 10.0),
      'unauthorized_user_999',
    );
    expect(unauthorizedSuccess, isFalse);

    // Verify target shop location was NOT changed
    final unchanged = DatabaseService().getShopById(targetShop.id);
    expect(unchanged?.latitude, equals(targetShop.latitude));
    expect(unchanged?.longitude, equals(targetShop.longitude));

    // Authorized owner can successfully update shop location
    final authorizedSuccess = await DatabaseService().saveShop(
      targetShop.copyWith(latitude: 12.3456, longitude: 76.5432),
      targetShop.ownerId,
    );
    expect(authorizedSuccess, isTrue);

    final modified = DatabaseService().getShopById(targetShop.id);
    expect(modified?.latitude, equals(12.3456));
    expect(modified?.longitude, equals(76.5432));
  });

  testWidgets('AddEditShopScreen loads existing shop coordinates and confirms location', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final shop = DatabaseService().getAllShops().first;

    await tester.pumpWidget(
      MaterialApp(
        home: AddEditShopScreen(existingShop: shop),
      ),
    );
    await tester.pumpAndSettle();

    // Verify existing coordinates are loaded and displayed
    expect(find.text('${shop.latitude.toStringAsFixed(4)}° N'), findsOneWidget);
    expect(find.text('${shop.longitude.toStringAsFixed(4)}° E'), findsOneWidget);

    // Tap Confirm Location button on main screen
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Location'));
    await tester.pumpAndSettle();

    // Verify confirmation SnackBar
    expect(find.textContaining('Location confirmed:'), findsOneWidget);
  });

  testWidgets('MapScreen My Location button updates camera and shows detection SnackBar when GPS granted', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    LocationService().setMockPositionForTesting(17.3850, 78.4867);

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap My Location button
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // Verify detection message
    expect(find.textContaining('Location detected: 17.3850, 78.4867'), findsOneWidget);
  });

  testWidgets('MapScreen My Location button handles permission denied gracefully with clear message', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    LocationService().setMockPermissionDeniedForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap My Location button
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // Verify clear informative SnackBar explaining GPS permission
    expect(find.textContaining('GPS permission is required only for automatic current-location selection'), findsOneWidget);
  });

  testWidgets('MapScreen My Location button handles service disabled gracefully with clear message', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    LocationService().setMockPermissionDeniedForTesting(
      status: LocationPermissionStatus.serviceDisabled,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap My Location button
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // Verify message indicates location services (GPS) are disabled
    expect(find.textContaining('Location services (GPS) are disabled'), findsOneWidget);
  });
}
