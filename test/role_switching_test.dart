import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcheck/data/sample_shops.dart';
import 'package:shopcheck/models/user.dart';
import 'package:shopcheck/screens/about_screen.dart';
import 'package:shopcheck/screens/app_shell.dart';
import 'package:shopcheck/screens/customer_shell.dart';
import 'package:shopcheck/screens/help_support_screen.dart';
import 'package:shopcheck/screens/home_screen.dart';
import 'package:shopcheck/screens/owner_dashboard_screen.dart';
import 'package:shopcheck/screens/owner_shell.dart';
import 'package:shopcheck/screens/profile_screen.dart';
import 'package:shopcheck/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';
import 'package:shopcheck/widgets/app_menu_button.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().resetForTesting(enablePersistence: false);
    await AuthService().init(enablePersistence: false);
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
  });

  testWidgets('Customer shell displays 5 bottom navigation items: Home, Search, Map, Favorites, Profile', (tester) async {
    await AuthService().login(phone: '555-123-4567', password: 'Password123');
    expect(AuthService().currentUser?.role, UserRole.customer);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomerShell), findsOneWidget);
    expect(find.byType(OwnerShell), findsNothing);

    // Verify 5 customer bottom navigation destinations
    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Search'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Map'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Favorites'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
  });

  testWidgets('Switching role to Shop Owner immediately switches UI shell to OwnerShell', (tester) async {
    await AuthService().login(phone: '555-123-4567', password: 'Password123');

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomerShell), findsOneWidget);

    // Switch role to Shop Owner
    await AuthService().switchRole(UserRole.shopOwner);
    await tester.pumpAndSettle();

    // Rebuilds immediately to OwnerShell
    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.byType(CustomerShell), findsNothing);

    // Verify 4 shop owner bottom navigation destinations
    expect(find.widgetWithText(NavigationDestination, 'Dashboard'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'My Shops'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add Shop'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
  });

  testWidgets('Switching role back to Customer restores CustomerShell immediately', (tester) async {
    await AuthService().login(phone: '555-987-6543', password: 'OwnerPass123');
    expect(AuthService().currentUser?.role, UserRole.shopOwner);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OwnerShell), findsOneWidget);

    // Switch role back to Customer
    await AuthService().switchRole(UserRole.customer);
    await tester.pumpAndSettle();

    expect(find.byType(CustomerShell), findsOneWidget);
    expect(find.byType(OwnerShell), findsNothing);
  });

  testWidgets('AppMenuButton displays role-specific actions for Customer', (tester) async {
    await AuthService().login(phone: '555-123-4567', password: 'Password123');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [AppMenuButton()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 3-dot menu button
    await tester.tap(find.byType(AppMenuButton));
    await tester.pumpAndSettle();

    // Verify customer-specific menu options
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('My Location'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About ShopCheck'), findsOneWidget);
    expect(find.text('Switch to Shop Owner'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('AppMenuButton displays role-specific actions for Shop Owner', (tester) async {
    await AuthService().login(phone: '555-987-6543', password: 'OwnerPass123');
    expect(AuthService().currentUser?.role, UserRole.shopOwner);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [AppMenuButton()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 3-dot menu button
    await tester.tap(find.byType(AppMenuButton));
    await tester.pumpAndSettle();

    // Verify shop-owner-specific menu options
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('My Shops'), findsOneWidget);
    expect(find.text('Add Shop'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About ShopCheck'), findsOneWidget);
    expect(find.text('Switch to Customer'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('SettingsScreen displays notifications, GPS check, map settings, role switch, and info links', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await AuthService().login(phone: '555-123-4567', password: 'Password123');

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Store Status Alerts'), findsOneWidget);
    expect(find.text('Location & GPS'), findsOneWidget);
    expect(find.text('Map Settings'), findsOneWidget);
    expect(find.text('Account Settings'), findsOneWidget);
    expect(find.text('Support & Info'), findsOneWidget);
    expect(find.text('Check GPS'), findsOneWidget);
    expect(find.text('Switch to Owner'), findsOneWidget);
  });

  testWidgets('AboutScreen renders tagline "Check before you travel." and mission statement', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About ShopCheck'), findsOneWidget);
    expect(find.textContaining('Check before you travel.'), findsOneWidget);
    expect(find.text('Our Mission'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Privacy Information'), findsOneWidget);
  });

  testWidgets('HelpSupportScreen renders FAQ topics, categories, and contact support button', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HelpSupportScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Getting Started'), findsOneWidget);
    expect(find.text('For Shop Owners'), findsOneWidget);
    expect(find.text('Location & GPS Help'), findsOneWidget);
    expect(find.text('Frequently Asked Questions (FAQ)'), findsOneWidget);
    expect(find.text('Contact Support Team'), findsOneWidget);
  });

  testWidgets('ProfileScreen displays user details, role badge, and allows editing profile name', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await AuthService().login(phone: '555-123-4567', password: 'Password123');

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('5551234567'), findsWidgets);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);

    // Open Edit Profile dialog
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Your Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ramesh Kumar');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(AuthService().currentUser?.name, 'Ramesh Kumar');
    expect(find.text('Ramesh Kumar'), findsOneWidget);
  });

  testWidgets('Shop Owner Dashboard displays 5 quick action cards and shop counts', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await AuthService().login(phone: '555-987-6543', password: 'OwnerPass123');

    final ownerShop = sampleShops.first.copyWith(
      id: 'owner_test_shop_1',
      name: 'Owner Supermarket',
      ownerId: '5559876543',
    );
    await DatabaseService().saveShop(ownerShop, '5559876543');

    await tester.pumpWidget(
      const MaterialApp(
        home: OwnerDashboardScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify 5 Quick Actions
    expect(find.text('+ Add Shop'), findsOneWidget);
    expect(find.text('My Shops'), findsWidgets);
    expect(find.text('Manage Opening Hours'), findsOneWidget);
    expect(find.text('Update Shop Location'), findsOneWidget);
    expect(find.text('Temporary Closure'), findsOneWidget);

    // Verify Dashboard stats
    expect(find.text('Open Now'), findsOneWidget);
    expect(find.text('Temporarily Closed'), findsOneWidget);
  });

  testWidgets('Customer Home screen displays Quick Actions (Search Shops, Nearby Shops, Open Now, Map, Saved)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await AuthService().login(phone: '555-123-4567', password: 'Password123');

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify customer quick action chips
    expect(find.text('Search Shops'), findsOneWidget);
    expect(find.text('Nearby Shops'), findsOneWidget);
    expect(find.text('Open Now'), findsWidgets);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });
}
