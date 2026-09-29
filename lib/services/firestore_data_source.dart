import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/shop.dart';
import '../models/user.dart';

/// Cloud Firestore data source providing real-time shop synchronization,
/// user profiles, favorites subcollections, and offline-resilient operations.
class FirestoreDataSource {
  static final FirestoreDataSource _instance = FirestoreDataSource._internal();
  factory FirestoreDataSource() => _instance;
  FirestoreDataSource._internal();

  /// Checks whether Firebase has been initialized in the current runtime environment.
  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _firestore {
    if (!isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  fb_auth.FirebaseAuth? get _auth {
    if (!isFirebaseAvailable) return null;
    try {
      return fb_auth.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Ensures a Firebase Auth session exists so Firestore security rules evaluate request.auth.
  Future<void> ensureFirebaseAuth() async {
    final auth = _auth;
    if (auth == null) return;
    try {
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } catch (e) {
      debugPrint('FirestoreDataSource: Anonymous auth bridge not available: $e');
    }
  }

  /// Real-time stream of all shops in the Firestore `shops` collection.
  Stream<List<Shop>> streamShops() {
    final firestore = _firestore;
    if (firestore == null) {
      return const Stream.empty();
    }

    return firestore
        .collection('shops')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Shop.fromFirestore(doc.data(), doc.id);
          }).toList();
        })
        .handleError((error) {
          debugPrint('Firestore streamShops error (offline or permission): $error');
          return <Shop>[];
        });
  }

  /// Saves or updates a shop in Firestore `shops/{shopId}`.
  /// Enforces ownerId match or system_admin privilege.
  Future<bool> saveShop(Shop shop, String userId) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      await ensureFirebaseAuth();
      final docRef = firestore.collection('shops').doc(shop.id);
      final existingDoc = await docRef.get();

      if (existingDoc.exists) {
        final data = existingDoc.data();
        final existingOwnerId = data?['ownerId'] as String?;
        if (existingOwnerId != null &&
            existingOwnerId != userId &&
            existingOwnerId != 'system_admin') {
          debugPrint('Firestore saveShop: Permission denied. User $userId is not owner.');
          return false;
        }
      }

      await docRef.set(shop.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore saveShop error: $e');
      return false;
    }
  }

  /// Updates temporary closure status in Firestore `shops/{shopId}`.
  Future<bool> updateTemporaryClosure(
    String shopId,
    String userId,
    bool isClosed, {
    String? reason,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      await ensureFirebaseAuth();
      final docRef = firestore.collection('shops').doc(shopId);
      final existingDoc = await docRef.get();
      if (!existingDoc.exists) return false;

      final data = existingDoc.data();
      final existingOwnerId = data?['ownerId'] as String?;
      if (existingOwnerId != null &&
          existingOwnerId != userId &&
          existingOwnerId != 'system_admin') {
        return false;
      }

      await docRef.update({
        'temporaryClosed': isClosed,
        'temporaryClosureReason': isClosed ? (reason ?? 'Temporarily closed by owner') : null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Firestore updateTemporaryClosure error: $e');
      return false;
    }
  }

  /// Updates shop GPS latitude and longitude in Firestore `shops/{shopId}`.
  Future<bool> updateShopLocation(
    String shopId,
    String userId,
    double latitude,
    double longitude,
  ) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      await ensureFirebaseAuth();
      final docRef = firestore.collection('shops').doc(shopId);
      final existingDoc = await docRef.get();
      if (!existingDoc.exists) return false;

      final data = existingDoc.data();
      final existingOwnerId = data?['ownerId'] as String?;
      if (existingOwnerId != null &&
          existingOwnerId != userId &&
          existingOwnerId != 'system_admin') {
        return false;
      }

      await docRef.update({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Firestore updateShopLocation error: $e');
      return false;
    }
  }

  /// Deletes a shop from Firestore `shops/{shopId}`.
  Future<bool> deleteShop(String shopId, String userId) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      await ensureFirebaseAuth();
      final docRef = firestore.collection('shops').doc(shopId);
      final existingDoc = await docRef.get();
      if (!existingDoc.exists) return false;

      final data = existingDoc.data();
      final existingOwnerId = data?['ownerId'] as String?;
      if (existingOwnerId != null &&
          existingOwnerId != userId &&
          existingOwnerId != 'system_admin') {
        return false;
      }

      await docRef.delete();
      return true;
    } catch (e) {
      debugPrint('Firestore deleteShop error: $e');
      return false;
    }
  }

  /// Saves cloud user profile to Firestore `users/{userId}`.
  /// Strictly omits passwords to prevent credential leakage.
  Future<bool> saveUserProfile(User user) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      await ensureFirebaseAuth();
      final userDoc = firestore.collection('users').doc(user.phone);
      await userDoc.set(user.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore saveUserProfile error: $e');
      return false;
    }
  }

  /// Fetches cloud user profile from Firestore `users/{userId}`.
  Future<User?> getUserProfile(String userId) async {
    final firestore = _firestore;
    if (firestore == null) return null;

    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return User.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Firestore getUserProfile error: $e');
      return null;
    }
  }

  /// Retrieves user favorites from Firestore `users/{userId}/favorites`.
  Future<Set<String>> getUserFavorites(String userId) async {
    final firestore = _firestore;
    if (firestore == null) return {};

    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      return snapshot.docs.map((d) => d.id).toSet();
    } catch (e) {
      debugPrint('Firestore getUserFavorites error: $e');
      return {};
    }
  }

  /// Adds or removes a favorite shop in Firestore `users/{userId}/favorites/{shopId}`.
  Future<bool> toggleFavorite(String userId, String shopId) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      await ensureFirebaseAuth();
      final favDoc = firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(shopId);

      final existing = await favDoc.get();
      if (existing.exists) {
        await favDoc.delete();
        return false; // Removed
      } else {
        await favDoc.set({
          'shopId': shopId,
          'createdAt': DateTime.now().toIso8601String(),
        });
        return true; // Added
      }
    } catch (e) {
      debugPrint('Firestore toggleFavorite error: $e');
      return false;
    }
  }

  /// Safely seeds initial local shops into Firestore using stable document IDs.
  /// Uses merge: true so existing shops are never duplicated.
  Future<void> migrateLocalShops(List<Shop> shops) async {
    final firestore = _firestore;
    if (firestore == null || shops.isEmpty) return;

    try {
      final existingDocs = await firestore.collection('shops').limit(1).get();
      // If collection already has data in cloud, do not overwrite
      if (existingDocs.docs.isNotEmpty) {
        return;
      }

      final batch = firestore.batch();
      for (final shop in shops) {
        final docRef = firestore.collection('shops').doc(shop.id);
        batch.set(docRef, shop.toFirestore(), SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('Firestore migration: Migrated ${shops.length} sample shops with stable IDs.');
    } catch (e) {
      debugPrint('Firestore migrateLocalShops error (offline or read-only): $e');
    }
  }
}
