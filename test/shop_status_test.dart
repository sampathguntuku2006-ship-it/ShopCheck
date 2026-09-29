import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/models/shop.dart';
import 'package:shopcheck/models/user.dart';
import 'package:shopcheck/screens/my_shops_screen.dart';
import 'package:shopcheck/screens/owner_dashboard_screen.dart';
import 'package:shopcheck/screens/shop_details_screen.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';
import 'package:shopcheck/widgets/shop_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Shop Opening-Hours Logic Tests', () {
    final standardShop = Shop(
      id: 'test_1',
      ownerId: '9876543210',
      name: 'Test Standard Shop',
      category: 'Grocery',
      categoryIcon: Icons.store,
      address: '100 Test Way',
      phone: '9876543210',
      distance: '0.5 km',
      description: 'Test shop description',
      weeklySchedule: {
        DateTime.monday: const DaySchedule(openHour: 9, openMinute: 0, closeHour: 21, closeMinute: 0),
        DateTime.tuesday: const DaySchedule(openHour: 9, openMinute: 0, closeHour: 21, closeMinute: 0),
        DateTime.wednesday: const DaySchedule(openHour: 9, openMinute: 0, closeHour: 21, closeMinute: 0),
        DateTime.thursday: const DaySchedule(openHour: 9, openMinute: 0, closeHour: 21, closeMinute: 0),
        DateTime.friday: const DaySchedule(openHour: 9, openMinute: 0, closeHour: 21, closeMinute: 0),
        DateTime.saturday: const DaySchedule(openHour: 9, openMinute: 0, closeHour: 21, closeMinute: 0),
        DateTime.sunday: const DaySchedule.closed(),
      },
    );

    test('Shop is OPEN during normal operating hours', () {
      final wednesdayMidday = DateTime(2026, 9, 9, 14, 30);
      final status = standardShop.getStatus(wednesdayMidday);

      expect(status.isOpen, isTrue);
      expect(status.isTemporarilyClosed, isFalse);
      expect(status.statusText, equals('OPEN'));
      expect(status.detailText, equals('Closes at 9:00 PM'));
      expect(status.statusColor, equals(const Color(0xFF16A34A)));
    });

    test('Shop is CLOSED in the morning before opening', () {
      final wednesdayMorning = DateTime(2026, 9, 9, 7, 45);
      final status = standardShop.getStatus(wednesdayMorning);

      expect(status.isOpen, isFalse);
      expect(status.statusText, equals('CLOSED'));
      expect(status.detailText, equals('Opens today at 9:00 AM'));
      expect(status.statusColor, equals(const Color(0xFFDC2626)));
    });

    test('Shop is CLOSED at night after closing and shows tomorrow opening', () {
      final wednesdayNight = DateTime(2026, 9, 9, 22, 15);
      final status = standardShop.getStatus(wednesdayNight);

      expect(status.isOpen, isFalse);
      expect(status.statusText, equals('CLOSED'));
      expect(status.detailText, equals('Opens tomorrow at 9:00 AM'));
      expect(status.statusColor, equals(const Color(0xFFDC2626)));
    });

    test('Shop is CLOSED on Sunday and indicates it opens on Monday', () {
      final sundayNoon = DateTime(2026, 9, 13, 12, 0);
      final status = standardShop.getStatus(sundayNoon);

      expect(status.isOpen, isFalse);
      expect(status.statusText, equals('CLOSED'));
      expect(status.detailText, equals('Opens tomorrow at 9:00 AM'));
    });

    test('24/7 Shop is always OPEN', () {
      final pharmacy247 = Shop(
        id: 'pharm_24',
        name: '24/7 Care',
        category: 'Pharmacy',
        categoryIcon: Icons.local_pharmacy,
        address: '1 Main St',
        phone: '555-1111',
        distance: '0.2 km',
        description: 'Open all the time',
        weeklySchedule: {
          DateTime.monday: const DaySchedule.allDay(),
          DateTime.tuesday: const DaySchedule.allDay(),
          DateTime.wednesday: const DaySchedule.allDay(),
          DateTime.thursday: const DaySchedule.allDay(),
          DateTime.friday: const DaySchedule.allDay(),
          DateTime.saturday: const DaySchedule.allDay(),
          DateTime.sunday: const DaySchedule.allDay(),
        },
      );

      final midnight = DateTime(2026, 9, 13, 3, 30);
      final status = pharmacy247.getStatus(midnight);

      expect(status.isOpen, isTrue);
      expect(status.statusText, equals('OPEN'));
      expect(status.detailText, equals('Open 24 Hours'));
    });
  });

  group('Temporary Closure Status & Engine Tests', () {
    final standardShop = Shop(
      id: 'test_temp',
      ownerId: '9876543210',
      name: 'Test Shop For Closure',
      category: 'Restaurant',
      categoryIcon: Icons.restaurant,
      address: '123 Food Street',
      phone: '9876543210',
      distance: '1.2 km',
      description: 'Tasty food',
      weeklySchedule: {
        DateTime.monday: const DaySchedule.allDay(),
        DateTime.tuesday: const DaySchedule.allDay(),
        DateTime.wednesday: const DaySchedule.allDay(),
        DateTime.thursday: const DaySchedule.allDay(),
        DateTime.friday: const DaySchedule.allDay(),
        DateTime.saturday: const DaySchedule.allDay(),
        DateTime.sunday: const DaySchedule.allDay(),
      },
    );

    test('When temporarily closed, opening hours do NOT override closure', () {
      final closedShop = standardShop.copyWith(
        isTemporarilyClosed: true,
        temporaryClosureReason: 'Renovation work',
      );

      final midday = DateTime(2026, 9, 9, 14, 0);
      final status = closedShop.getStatus(midday);

      expect(status.isOpen, isFalse);
      expect(status.isTemporarilyClosed, isTrue);
      expect(status.statusText, equals('TEMPORARILY CLOSED'));
      expect(status.detailText, equals('Renovation work'));
      expect(status.statusColor, equals(const Color(0xFFD97706)));
      expect(status.backgroundColor, equals(const Color(0xFFFEF3C7)));
    });

    test('Reopening shop immediately restores normal schedule calculation', () {
      final closedShop = standardShop.copyWith(isTemporarilyClosed: true);
      expect(closedShop.getStatus().isTemporarilyClosed, isTrue);

      final reopenedShop = closedShop.copyWith(isTemporarilyClosed: false, temporaryClosureReason: null);
      final midday = DateTime(2026, 9, 9, 14, 0);
      final reopenedStatus = reopenedShop.getStatus(midday);

      expect(reopenedStatus.isOpen, isTrue);
      expect(reopenedStatus.isTemporarilyClosed, isFalse);
      expect(reopenedStatus.statusText, equals('OPEN'));
    });
  });

  group('DatabaseService Real-time & Permission Tests', () {
    late DatabaseService db;
    const ownerPhone = '9876543210';
    const otherPhone = '1122334455';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = DatabaseService();
      await db.init(enablePersistence: false);
    });

    test('Only shop owner or admin can toggle temporary closure', () async {
      final myShop = Shop(
        id: 'owner_shop_1',
        ownerId: ownerPhone,
        name: 'Owner Special Store',
        category: 'Grocery',
        categoryIcon: Icons.shopping_basket,
        address: 'Banjara Hills',
        phone: ownerPhone,
        distance: '1.0 km',
        description: 'Quality goods',
        weeklySchedule: {
          DateTime.monday: const DaySchedule.allDay(),
        },
      );

      await db.saveShop(myShop, ownerPhone);

      // Unauthorized user attempts to close the shop
      final unauthorizedResult = await db.toggleTemporaryClosure(
        'owner_shop_1',
        otherPhone,
        reason: 'Malicious close',
      );
      expect(unauthorizedResult, isFalse);
      expect(db.getShopById('owner_shop_1')!.isTemporarilyClosed, isFalse);

      // Authorized owner closes the shop
      final authorizedResult = await db.toggleTemporaryClosure(
        'owner_shop_1',
        ownerPhone,
        reason: 'Owner vacation',
      );
      expect(authorizedResult, isTrue);
      final updatedShop = db.getShopById('owner_shop_1')!;
      expect(updatedShop.isTemporarilyClosed, isTrue);
      expect(updatedShop.temporaryClosureReason, equals('Owner vacation'));

      // Authorized owner reopens the shop
      final reopenResult = await db.toggleTemporaryClosure('owner_shop_1', ownerPhone);
      expect(reopenResult, isTrue);
      expect(db.getShopById('owner_shop_1')!.isTemporarilyClosed, isFalse);
    });

    test('DatabaseService notifies ValueListenable on closure toggle for real-time updates', () async {
      final testShop = Shop(
        id: 'notify_shop_1',
        ownerId: ownerPhone,
        name: 'Realtime Notifier Store',
        category: 'Pharmacy',
        categoryIcon: Icons.local_pharmacy,
        address: 'Secunderabad',
        phone: ownerPhone,
        distance: '2.0 km',
        description: 'Fast service',
        weeklySchedule: {},
      );

      await db.saveShop(testShop, ownerPhone);

      int notifyCount = 0;
      void listener() {
        notifyCount++;
      }

      db.shopsNotifier.addListener(listener);
      await db.toggleTemporaryClosure('notify_shop_1', ownerPhone);

      expect(notifyCount, greaterThan(0));
      db.shopsNotifier.removeListener(listener);
    });
  });

  group('UI Tests: ShopCard, ShopDetailsScreen, MyShopsScreen, OwnerDashboardScreen', () {
    const ownerPhone = '9876543210';

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      DatabaseService().resetForTesting();
      final db = DatabaseService();
      await db.init(enablePersistence: false);

      AuthService().resetForTesting();
      final auth = AuthService();
      await auth.init(enablePersistence: false);
      await auth.register(
        phone: ownerPhone,
        password: 'Password123',
        role: UserRole.shopOwner,
      );
    });

    testWidgets('ShopCard displays TEMPORARILY CLOSED badge', (tester) async {
      final tempClosedShop = Shop(
        id: 'card_temp_shop',
        ownerId: ownerPhone,
        name: 'Temporary Pause Mart',
        category: 'Grocery',
        categoryIcon: Icons.shopping_basket,
        address: 'Hitech City',
        phone: ownerPhone,
        distance: '1.5 km',
        description: 'Great selection',
        isTemporarilyClosed: true,
        temporaryClosureReason: 'Store Renovation',
        weeklySchedule: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopCard(shop: tempClosedShop),
          ),
        ),
      );

      expect(find.text('Temporary Pause Mart'), findsOneWidget);
      expect(find.text('TEMPORARILY CLOSED'), findsOneWidget);
      expect(find.text('Store Renovation'), findsOneWidget);
    });

    testWidgets('ShopDetailsScreen displays clear "Temporarily closed" banner', (tester) async {
      final tempClosedShop = Shop(
        id: 'details_temp_shop',
        ownerId: ownerPhone,
        name: 'Details Pause Mart',
        category: 'Grocery',
        categoryIcon: Icons.shopping_basket,
        address: 'Madhapur',
        phone: ownerPhone,
        distance: '2.0 km',
        description: 'Details description',
        isTemporarilyClosed: true,
        temporaryClosureReason: 'Annual inventory check',
        weeklySchedule: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ShopDetailsScreen(shop: tempClosedShop),
        ),
      );

      expect(find.text('Details Pause Mart'), findsAtLeastNWidgets(1));
      expect(find.text('TEMPORARILY CLOSED'), findsOneWidget);
      expect(find.textContaining('Temporarily closed'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Annual inventory check'), findsAtLeastNWidgets(1));
    });

    testWidgets('OwnerDashboardScreen displays 4 statistics: Total Shops, Open Now, Closed, Temporarily Closed', (tester) async {
      final db = DatabaseService();
      final shop1 = Shop(
        id: 'dash_shop_1',
        ownerId: ownerPhone,
        name: 'Open Always Shop',
        category: 'Pharmacy',
        categoryIcon: Icons.local_pharmacy,
        address: 'Jubilee Hills',
        phone: ownerPhone,
        distance: '1.0 km',
        description: 'Always open',
        weeklySchedule: {
          DateTime.monday: const DaySchedule.allDay(),
          DateTime.tuesday: const DaySchedule.allDay(),
          DateTime.wednesday: const DaySchedule.allDay(),
          DateTime.thursday: const DaySchedule.allDay(),
          DateTime.friday: const DaySchedule.allDay(),
          DateTime.saturday: const DaySchedule.allDay(),
          DateTime.sunday: const DaySchedule.allDay(),
        },
      );

      final shop2 = Shop(
        id: 'dash_shop_2',
        ownerId: ownerPhone,
        name: 'Paused Shop',
        category: 'Grocery',
        categoryIcon: Icons.shopping_basket,
        address: 'Gachibowli',
        phone: ownerPhone,
        distance: '2.5 km',
        description: 'Paused for now',
        isTemporarilyClosed: true,
        temporaryClosureReason: 'Flooring revamp',
        weeklySchedule: {},
      );

      await db.saveShop(shop1, ownerPhone);
      await db.saveShop(shop2, ownerPhone);

      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Shops'), findsOneWidget);
      expect(find.text('Open Now'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Temporarily Closed'), findsOneWidget);
    });

    testWidgets('MyShopsScreen renders shop cards with Edit and Temporarily Close Shop buttons and confirmation dialog', (tester) async {
      DatabaseService().resetForTesting();
      final db = DatabaseService();
      await db.init(enablePersistence: false);
      final shop = Shop(
        id: 'myshops_test_1',
        ownerId: ownerPhone,
        name: 'My Central Store',
        category: 'Clothing',
        categoryIcon: Icons.checkroom,
        address: 'Ameerpet',
        city: 'Hyderabad',
        state: 'Telangana',
        pincode: '500016',
        phone: ownerPhone,
        distance: '3.0 km',
        description: 'Fashion apparel',
        weeklySchedule: {
          DateTime.monday: const DaySchedule(openHour: 9, closeHour: 21),
          DateTime.tuesday: const DaySchedule(openHour: 9, closeHour: 21),
          DateTime.wednesday: const DaySchedule(openHour: 9, closeHour: 21),
          DateTime.thursday: const DaySchedule(openHour: 9, closeHour: 21),
          DateTime.friday: const DaySchedule(openHour: 9, closeHour: 21),
          DateTime.saturday: const DaySchedule(openHour: 9, closeHour: 21),
          DateTime.sunday: const DaySchedule(openHour: 9, closeHour: 21),
        },
      );

      await db.saveShop(shop, ownerPhone);

      await tester.pumpWidget(
        const MaterialApp(
          home: MyShopsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Central Store'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Temporarily Close Shop'), findsOneWidget);
      expect(find.textContaining("Today's Hours:"), findsOneWidget);

      // Tap Temporarily Close Shop button
      await tester.tap(find.text('Temporarily Close Shop'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog title and buttons
      expect(find.text('Temporarily close this shop?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Verify button changes to 'Reopen Shop'
      expect(find.text('Reopen Shop'), findsOneWidget);
    });
  });
}
