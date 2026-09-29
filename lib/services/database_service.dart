import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/sample_shops.dart';
import '../models/shop.dart';
import 'firestore_data_source.dart';

/// Database and repository service managing persistent shop records,
/// opening hours, locations, and temporary closures.
///
/// Architecture: Multi-tier repository
///   DatabaseService
///        ↓
///   FirestoreDataSource (Live cloud sync, real-time snapshot stream)
///        ↓
///   Local SharedPreferences Cache (Offline resilience, instant startup & testing)
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _shopsPrefKey = 'shopcheck_persistent_shops';
  static const String _favoritesPrefKey = 'shopcheck_persistent_favorites';

  final List<Shop> _shops = [];
  final ValueNotifier<List<Shop>> shopsNotifier = ValueNotifier<List<Shop>>([]);
  final Map<String, Set<String>> _userFavorites = {};
  final ValueNotifier<int> favoritesRevisionNotifier = ValueNotifier<int>(0);

  final FirestoreDataSource _firestoreDataSource = FirestoreDataSource();
  StreamSubscription<List<Shop>>? _firestoreSubscription;

  bool _initialized = false;
  bool _isCloudSyncActive = false;

  /// Returns true if Firestore cloud synchronization is active.
  bool get isCloudSyncActive => _isCloudSyncActive;

  /// Reactive notifier for cloud connectivity status
  final ValueNotifier<bool> cloudSyncNotifier = ValueNotifier<bool>(false);

  List<Shop> get shops => List.unmodifiable(_shops);

  /// Initializes the database from local persistent storage,
  /// then seamlessly establishes Cloud Firestore real-time synchronization if configured.
  Future<void> init({bool enablePersistence = true}) async {
    if (_initialized) return;

    _shops.clear();

    // 1. Instant local cache load
    if (enablePersistence) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString(_shopsPrefKey);
        if (rawJson != null && rawJson.isNotEmpty) {
          final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
          for (final item in list) {
            _shops.add(Shop.fromJson(item as Map<String, dynamic>));
          }
        }

        final favsRaw = prefs.getString(_favoritesPrefKey);
        if (favsRaw != null && favsRaw.isNotEmpty) {
          final Map<String, dynamic> decoded = jsonDecode(favsRaw) as Map<String, dynamic>;
          _userFavorites.clear();
          decoded.forEach((phone, list) {
            if (list is List) {
              _userFavorites[phone] = list.map((e) => e.toString()).toSet();
            }
          });
        }
      } catch (e) {
        debugPrint('DatabaseService local cache load error: $e');
      }
    }

    // 2. Seed default sample Indian shops if local cache is empty
    if (_shops.isEmpty) {
      _shops.addAll(sampleShops);
      if (enablePersistence) {
        await _saveToPrefs();
      }
    }

    shopsNotifier.value = List.unmodifiable(_shops);
    _initialized = true;

    // 3. Connect to Firestore Cloud Sync if Firebase is available
    if (_firestoreDataSource.isFirebaseAvailable) {
      _connectFirestoreSync(enablePersistence);
    } else {
      _isCloudSyncActive = false;
      cloudSyncNotifier.value = false;
    }
  }

  void _connectFirestoreSync(bool enablePersistence) {
    try {
      _firestoreSubscription?.cancel();
      _firestoreSubscription = _firestoreDataSource.streamShops().listen(
        (cloudShops) async {
          if (cloudShops.isNotEmpty) {
            _shops.clear();
            _shops.addAll(cloudShops);
            shopsNotifier.value = List.unmodifiable(_shops);
            _isCloudSyncActive = true;
            cloudSyncNotifier.value = true;
            if (enablePersistence) {
              await _saveToPrefs();
            }
          } else {
            // Cloud collection is empty: safely migrate sample shops with stable IDs
            await _firestoreDataSource.migrateLocalShops(_shops);
            _isCloudSyncActive = true;
            cloudSyncNotifier.value = true;
          }
        },
        onError: (err) {
          debugPrint('Firestore sync stream error: $err');
          _isCloudSyncActive = false;
          cloudSyncNotifier.value = false;
        },
      );
    } catch (e) {
      debugPrint('Firestore connection error: $e');
      _isCloudSyncActive = false;
      cloudSyncNotifier.value = false;
    }
  }

  /// Returns all shops visible to customers.
  List<Shop> getAllShops() => List.unmodifiable(_shops);

  /// Returns only shops owned by the specified [ownerId].
  List<Shop> getShopsByOwner(String ownerId) {
    return _shops.where((s) => s.ownerId == ownerId).toList();
  }

  /// Retrieves a single shop by its unique ID.
  Shop? getShopById(String id) {
    try {
      return _shops.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Saves a new shop or updates an existing shop.
  /// Enforces ownership: only the registered owner can modify their shop.
  Future<bool> saveShop(Shop shop, String requestorUserId) async {
    final existingIndex = _shops.indexWhere((s) => s.id == shop.id);
    Shop shopToSave;

    if (existingIndex >= 0) {
      final existing = _shops[existingIndex];
      // Security Check: Only the registered owner or admin can edit
      if (existing.ownerId != requestorUserId && existing.ownerId != 'system_admin') {
        return false;
      }
      shopToSave = shop.copyWith(
        ownerId: existing.ownerId,
        updatedAt: DateTime.now(),
      );
      _shops[existingIndex] = shopToSave;
    } else {
      // New shop: assign requestor as owner
      shopToSave = shop.copyWith(
        id: shop.id.isEmpty ? 'shop_${DateTime.now().millisecondsSinceEpoch}' : shop.id,
        ownerId: requestorUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _shops.insert(0, shopToSave);
    }

    shopsNotifier.value = List.unmodifiable(_shops);
    await _saveToPrefs();

    // Cloud synchronization
    if (_firestoreDataSource.isFirebaseAvailable) {
      await _firestoreDataSource.saveShop(shopToSave, requestorUserId);
    }

    return true;
  }

  /// Updates shop GPS coordinates and synchronizes to cloud.
  Future<bool> updateShopLocation(
    String shopId,
    String requestorUserId,
    double latitude,
    double longitude,
  ) async {
    final index = _shops.indexWhere((s) => s.id == shopId);
    if (index < 0) return false;

    final shop = _shops[index];
    if (shop.ownerId != requestorUserId && shop.ownerId != 'system_admin') {
      return false;
    }

    final updated = shop.copyWith(
      latitude: latitude,
      longitude: longitude,
      updatedAt: DateTime.now(),
    );
    _shops[index] = updated;
    shopsNotifier.value = List.unmodifiable(_shops);
    await _saveToPrefs();

    if (_firestoreDataSource.isFirebaseAvailable) {
      await _firestoreDataSource.updateShopLocation(shopId, requestorUserId, latitude, longitude);
    }

    return true;
  }

  /// Toggles temporary closure for a shop.
  /// Enforces ownership check.
  Future<bool> toggleTemporaryClosure(
    String shopId,
    String requestorUserId, {
    String? reason,
  }) async {
    final index = _shops.indexWhere((s) => s.id == shopId);
    if (index < 0) return false;

    final shop = _shops[index];
    if (shop.ownerId != requestorUserId && shop.ownerId != 'system_admin') {
      return false;
    }

    final newStatus = !shop.isTemporarilyClosed;
    final updated = shop.copyWith(
      isTemporarilyClosed: newStatus,
      temporaryClosureReason: newStatus ? (reason ?? 'Temporarily closed by owner') : null,
      updatedAt: DateTime.now(),
    );
    _shops[index] = updated;

    shopsNotifier.value = List.unmodifiable(_shops);
    await _saveToPrefs();

    if (_firestoreDataSource.isFirebaseAvailable) {
      await _firestoreDataSource.updateTemporaryClosure(
        shopId,
        requestorUserId,
        newStatus,
        reason: reason,
      );
    }

    return true;
  }

  /// Deletes a shop if requestor is the owner.
  Future<bool> deleteShop(String shopId, String requestorUserId) async {
    final index = _shops.indexWhere((s) => s.id == shopId);
    if (index < 0) return false;

    final shop = _shops[index];
    if (shop.ownerId != requestorUserId && shop.ownerId != 'system_admin') {
      return false;
    }

    _shops.removeAt(index);
    shopsNotifier.value = List.unmodifiable(_shops);
    await _saveToPrefs();

    if (_firestoreDataSource.isFirebaseAvailable) {
      await _firestoreDataSource.deleteShop(shopId, requestorUserId);
    }

    return true;
  }

  /// Returns set of favorite shop IDs for a given customer.
  Set<String> getFavorites(String customerPhone) {
    return Set.unmodifiable(_userFavorites[customerPhone] ?? const {});
  }

  /// Checks if a shop is in the customer's favorites.
  bool isFavorite(String shopId, String customerPhone) {
    return _userFavorites[customerPhone]?.contains(shopId) ?? false;
  }

  /// Adds a shop to customer's favorites.
  Future<bool> addFavorite(String shopId, String customerPhone) async {
    final userFavs = _userFavorites.putIfAbsent(customerPhone, () => <String>{});
    final added = userFavs.add(shopId);
    if (added) {
      favoritesRevisionNotifier.value++;
      await _saveFavoritesToPrefs();

      if (_firestoreDataSource.isFirebaseAvailable) {
        await _firestoreDataSource.toggleFavorite(customerPhone, shopId);
      }
    }
    return added;
  }

  /// Removes a shop from customer's favorites.
  Future<bool> removeFavorite(String shopId, String customerPhone) async {
    final userFavs = _userFavorites[customerPhone];
    if (userFavs != null && userFavs.remove(shopId)) {
      favoritesRevisionNotifier.value++;
      await _saveFavoritesToPrefs();

      if (_firestoreDataSource.isFirebaseAvailable) {
        await _firestoreDataSource.toggleFavorite(customerPhone, shopId);
      }
      return true;
    }
    return false;
  }

  /// Toggles favorite status for a customer.
  Future<bool> toggleFavorite(String shopId, String customerPhone) async {
    if (isFavorite(shopId, customerPhone)) {
      await removeFavorite(shopId, customerPhone);
      return false;
    } else {
      await addFavorite(shopId, customerPhone);
      return true;
    }
  }

  /// Retrieves list of favorite Shop objects for a customer.
  List<Shop> getFavoriteShops(String customerPhone) {
    final favIds = getFavorites(customerPhone);
    return _shops.where((s) => favIds.contains(s.id)).toList();
  }

  /// Loads user favorites from Firestore if available.
  Future<void> syncCloudFavorites(String customerPhone) async {
    if (!_firestoreDataSource.isFirebaseAvailable) return;
    try {
      final cloudFavs = await _firestoreDataSource.getUserFavorites(customerPhone);
      if (cloudFavs.isNotEmpty) {
        _userFavorites[customerPhone] = cloudFavs;
        favoritesRevisionNotifier.value++;
        await _saveFavoritesToPrefs();
      }
    } catch (e) {
      debugPrint('DatabaseService syncCloudFavorites error: $e');
    }
  }

  Future<void> _saveFavoritesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, List<String>> mapToSave = {};
      _userFavorites.forEach((phone, set) {
        mapToSave[phone] = set.toList();
      });
      await prefs.setString(_favoritesPrefKey, jsonEncode(mapToSave));
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _shops.map((s) => s.toJson()).toList();
      await prefs.setString(_shopsPrefKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Resets state for unit testing.
  void resetForTesting() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _shops.clear();
    _initialized = false;
    _isCloudSyncActive = false;
    shopsNotifier.value = [];
    _userFavorites.clear();
    favoritesRevisionNotifier.value = 0;
    cloudSyncNotifier.value = false;
  }
}
