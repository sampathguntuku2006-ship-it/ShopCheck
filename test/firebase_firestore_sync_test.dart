import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/models/shop.dart';
import 'package:shopcheck/models/user.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
    AuthService().resetForTesting();
    await AuthService().init(enablePersistence: false);
  });

  group('Firestore Data Structures & Field Verification Tests', () {
    final testShop = Shop(
      id: 'shop_101',
      ownerId: '9849012345',
      name: 'Cloud Hyderabad Mart',
      category: 'Grocery & Supermarket',
      categoryIcon: Icons.shopping_basket_rounded,
      address: 'Plot 42, Hitech City',
      city: 'Hyderabad',
      state: 'Telangana',
      pincode: '500081',
      latitude: 17.4485,
      longitude: 78.3741,
      phone: '+91 98490 12345',
      distance: '1.2 km',
      description: 'Finest groceries and fresh vegetables.',
      isTemporarilyClosed: false,
      weeklySchedule: {
        DateTime.monday: const DaySchedule(openHour: 8, openMinute: 0, closeHour: 22, closeMinute: 0),
        DateTime.sunday: const DaySchedule.closed(),
      },
    );

    test('Shop.toFirestore() contains all 16 required Firestore fields', () {
      final firestoreData = testShop.toFirestore();

      expect(firestoreData['shopId'], equals('shop_101'));
      expect(firestoreData['ownerId'], equals('9849012345'));
      expect(firestoreData['name'], equals('Cloud Hyderabad Mart'));
      expect(firestoreData['category'], equals('Grocery & Supermarket'));
      expect(firestoreData['phone'], equals('+91 98490 12345'));
      expect(firestoreData['address'], equals('Plot 42, Hitech City'));
      expect(firestoreData['city'], equals('Hyderabad'));
      expect(firestoreData['state'], equals('Telangana'));
      expect(firestoreData['pin'], equals('500081'));
      expect(firestoreData['description'], equals('Finest groceries and fresh vegetables.'));
      expect(firestoreData['latitude'], equals(17.4485));
      expect(firestoreData['longitude'], equals(78.3741));
      expect(firestoreData['openingHours'], isA<Map>());
      expect(firestoreData['temporaryClosed'], isFalse);
      expect(firestoreData['createdAt'], isNotNull);
      expect(firestoreData['updatedAt'], isNotNull);
    });

    test('Shop.fromFirestore() reconstructs model accurately from Firestore schema', () {
      final firestoreDoc = {
        'shopId': 'cloud_shop_202',
        'ownerId': '9849055555',
        'name': 'Cloud Pharmacy',
        'category': 'Pharmacy & Wellness',
        'phone': '+91 98490 55555',
        'address': 'Banjara Hills Road 12',
        'city': 'Hyderabad',
        'state': 'Telangana',
        'pin': '500034',
        'description': '24/7 medicines and wellness.',
        'latitude': 17.4150,
        'longitude': 78.4350,
        'openingHours': {
          '1': {'isOpen': true, 'openHour': 9, 'openMinute': 0, 'closeHour': 21, 'closeMinute': 0},
        },
        'temporaryClosed': true,
        'temporaryClosureReason': 'Sanitization in progress',
        'createdAt': '2026-09-01T10:00:00.000Z',
        'updatedAt': '2026-09-20T12:00:00.000Z',
      };

      final shop = Shop.fromFirestore(firestoreDoc, 'cloud_shop_202');

      expect(shop.id, equals('cloud_shop_202'));
      expect(shop.ownerId, equals('9849055555'));
      expect(shop.name, equals('Cloud Pharmacy'));
      expect(shop.pincode, equals('500034'));
      expect(shop.pin, equals('500034'));
      expect(shop.isTemporarilyClosed, isTrue);
      expect(shop.temporaryClosed, isTrue);
      expect(shop.temporaryClosureReason, equals('Sanitization in progress'));
      expect(shop.getStatus().statusText, equals('TEMPORARILY CLOSED'));
      expect(shop.getStatus().isTemporarilyClosed, isTrue);
    });

    test('User.toFirestore() contains required fields and STRICTLY omits plaintext passwords', () {
      final user = User(
        phone: '9876543210',
        salt: 'cryptographic_salt_123',
        passwordHash: 'salted_sha256_hash_abc',
        createdAt: DateTime(2026, 1, 1),
        role: UserRole.shopOwner,
        name: 'John Store Owner',
      );

      final firestoreMap = user.toFirestore();

      expect(firestoreMap['name'], equals('John Store Owner'));
      expect(firestoreMap['phone'], equals('9876543210'));
      expect(firestoreMap['role'], equals('shopOwner'));
      expect(firestoreMap['createdAt'], isNotNull);
      expect(firestoreMap['updatedAt'], isNotNull);

      // Security requirement: No plaintext passwords or salt exposed in Firestore
      expect(firestoreMap.containsKey('password'), isFalse);
      expect(firestoreMap.containsKey('passwordHash'), isFalse);
      expect(firestoreMap.containsKey('salt'), isFalse);
    });
  });

  group('Firestore Security & Multi-Role Ownership Tests', () {
    const ownerA = '9849011111';
    const ownerB = '9849022222';
    const customer = '9849033333';

    test('Owner A can create and modify their own shop', () async {
      final db = DatabaseService();
      final shop = Shop(
        id: 'owner_a_store',
        ownerId: ownerA,
        name: 'Owner A Store',
        category: 'Grocery',
        categoryIcon: Icons.store,
        address: 'Secunderabad',
        phone: ownerA,
        distance: '1.0 km',
        description: 'Quality store',
        weeklySchedule: {},
      );

      final saveResult = await db.saveShop(shop, ownerA);
      expect(saveResult, isTrue);

      // Update location
      final locationResult = await db.updateShopLocation('owner_a_store', ownerA, 17.4399, 78.4983);
      expect(locationResult, isTrue);
      expect(db.getShopById('owner_a_store')!.latitude, equals(17.4399));

      // Toggle temporary closure
      final closureResult = await db.toggleTemporaryClosure('owner_a_store', ownerA, reason: 'Inventory check');
      expect(closureResult, isTrue);
      expect(db.getShopById('owner_a_store')!.isTemporarilyClosed, isTrue);
    });

    test('Owner B CANNOT modify Owner A shop', () async {
      final db = DatabaseService();
      final shop = Shop(
        id: 'owner_a_store_2',
        ownerId: ownerA,
        name: 'Owner A Store 2',
        category: 'Grocery',
        categoryIcon: Icons.store,
        address: 'Banjara Hills',
        phone: ownerA,
        distance: '1.0 km',
        description: 'Quality store',
        weeklySchedule: {},
      );
      await db.saveShop(shop, ownerA);

      // Owner B attempts to edit
      final editResult = await db.saveShop(shop.copyWith(name: 'Hacked by Owner B'), ownerB);
      expect(editResult, isFalse);

      // Owner B attempts to change temporary closure
      final closureResult = await db.toggleTemporaryClosure('owner_a_store_2', ownerB);
      expect(closureResult, isFalse);

      // Owner B attempts to update location
      final locationResult = await db.updateShopLocation('owner_a_store_2', ownerB, 10.0, 10.0);
      expect(locationResult, isFalse);

      // Owner B attempts to delete
      final deleteResult = await db.deleteShop('owner_a_store_2', ownerB);
      expect(deleteResult, isFalse);
    });

    test('Customer CANNOT modify shop documents', () async {
      final db = DatabaseService();
      final shop = Shop(
        id: 'owner_a_store_3',
        ownerId: ownerA,
        name: 'Owner A Store 3',
        category: 'Grocery',
        categoryIcon: Icons.store,
        address: 'Gachibowli',
        phone: ownerA,
        distance: '1.0 km',
        description: 'Quality store',
        weeklySchedule: {},
      );
      await db.saveShop(shop, ownerA);

      // Customer attempts to modify
      final customerEdit = await db.saveShop(shop.copyWith(name: 'Customer Defaced'), customer);
      expect(customerEdit, isFalse);

      final customerClosure = await db.toggleTemporaryClosure('owner_a_store_3', customer);
      expect(customerClosure, isFalse);

      final customerDelete = await db.deleteShop('owner_a_store_3', customer);
      expect(customerDelete, isFalse);

      // Customer CAN add to favorites
      final favResult = await db.addFavorite('owner_a_store_3', customer);
      expect(favResult, isTrue);
      expect(db.isFavorite('owner_a_store_3', customer), isTrue);
    });
  });

  group('Offline Resilience & Local Cache Fallback Tests', () {
    test('App boots without crashing when Firebase is uninitialized or offline', () async {
      final db = DatabaseService();
      expect(db.getAllShops(), isNotEmpty);
      expect(db.isCloudSyncActive, isFalse);
      expect(db.cloudSyncNotifier.value, isFalse);
    });

    test('Sample shops use stable IDs preventing duplication', () async {
      final db = DatabaseService();
      final allShops = db.getAllShops();
      final ids = allShops.map((s) => s.id).toList();
      final uniqueIds = ids.toSet();

      // No duplicated IDs
      expect(ids.length, equals(uniqueIds.length));
      expect(ids, contains('shop_1'));
      expect(ids, contains('shop_2'));
    });
  });
}
