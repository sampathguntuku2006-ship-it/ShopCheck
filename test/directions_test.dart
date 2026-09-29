// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:shopcheck/models/shop.dart';
import 'package:shopcheck/screens/shop_details_screen.dart';
import 'package:shopcheck/services/location_service.dart';

class MockUrlLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  String? lastLaunchedUrl;
  PreferredLaunchMode? lastLaunchMode;
  bool shouldFailExternalNonBrowser = false;
  bool shouldFailAll = false;

  @override
  Future<bool> canLaunch(String url) async => !shouldFailAll;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    lastLaunchMode = options.mode;
    if (shouldFailAll) return false;
    if (shouldFailExternalNonBrowser && options.mode == PreferredLaunchMode.externalNonBrowserApplication) {
      return false;
    }
    return true;
  }
}

void main() {
  late MockUrlLauncher mockLauncher;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockLauncher;
    LocationService().resetForTesting();
  });

  tearDown(() {
    LocationService().resetForTesting();
  });

  final testShop = Shop(
    id: 'test_shop_1',
    ownerId: 'owner_1',
    name: 'Apollo Pharmacy Banjara',
    category: 'Pharmacy',
    categoryIcon: Icons.local_pharmacy_rounded,
    address: 'Road No. 2, Banjara Hills',
    city: 'Hyderabad',
    state: 'Telangana',
    pincode: '500034',
    latitude: 17.4239,
    longitude: 78.4482,
    phone: '+91 98490 12345',
    distance: '1.5 km away',
    description: '24x7 pharmacy and medical supplies.',
    weeklySchedule: {
      1: const DaySchedule.allDay(),
    },
  );

  testWidgets('Get Directions button is present on Shop Details screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: testShop),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get Directions'), findsOneWidget);
    expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
  });

  testWidgets('Get Directions uses customer GPS location when available', (tester) async {
    // Mock customer location in Hyderabad
    LocationService().setMockPositionForTesting(17.3850, 78.4867);

    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: testShop),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Get Directions"
    await tester.tap(find.text('Get Directions'));
    await tester.pumpAndSettle();

    // Verify launched URL contains customer origin and actual shop coordinates as destination
    expect(mockLauncher.lastLaunchedUrl, isNotNull);
    final launched = mockLauncher.lastLaunchedUrl!;
    expect(launched, contains('origin=17.385,78.4867'));
    expect(launched, contains('destination=17.4239,78.4482'));

    // Should not show default fallback snackbar
    expect(find.textContaining('Using default location'), findsNothing);
  });

  testWidgets('Get Directions falls back to India default location when location unavailable', (tester) async {
    // LocationService has permission denied
    LocationService().setMockPermissionDeniedForTesting();

    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: testShop),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Get Directions"
    await tester.tap(find.text('Get Directions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify snackbar informing user about default fallback
    expect(find.textContaining('Could not get your current location'), findsOneWidget);
    expect(find.textContaining('Using default location for directions'), findsOneWidget);

    await tester.pumpAndSettle();

    // Verify launched URL contains India default location (20.5937, 78.9629)
    expect(mockLauncher.lastLaunchedUrl, isNotNull);
    final launched = mockLauncher.lastLaunchedUrl!;
    expect(launched, contains('origin=${LocationService.defaultIndiaLat},${LocationService.defaultIndiaLng}'));
    expect(launched, contains('destination=17.4239,78.4482'));
  });

  testWidgets('Get Directions falls back to browser when Google Maps app is unavailable', (tester) async {
    mockLauncher.shouldFailExternalNonBrowser = true;
    LocationService().setMockPositionForTesting(17.3850, 78.4867);

    await tester.pumpWidget(
      MaterialApp(
        home: ShopDetailsScreen(shop: testShop),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Get Directions"
    await tester.tap(find.text('Get Directions'));
    await tester.pumpAndSettle();

    // Should have fallen back to externalApplication (browser)
    expect(mockLauncher.lastLaunchMode, equals(PreferredLaunchMode.externalApplication));
    expect(mockLauncher.lastLaunchedUrl, contains('destination=17.4239,78.4482'));
  });
}
