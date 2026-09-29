import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'firestore_data_source.dart';

/// Result object for authentication actions.
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(User user) =>
      AuthResult._(isSuccess: true, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}

/// Authentication service managing user registration, login, session state,
/// and salted password hashing. Passwords are NEVER stored in plain text.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _usersPrefKey = 'shopcheck_registered_users';
  static const String _sessionPrefKey = 'shopcheck_logged_in_phone';

  final Map<String, User> _users = {};
  User? _currentUser;
  final ValueNotifier<User?> userNotifier = ValueNotifier<User?>(null);
  bool _initialized = false;
  bool _persistenceEnabled = true;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Initializes storage and seeds default demo credentials.
  Future<void> init({bool enablePersistence = true}) async {
    _persistenceEnabled = enablePersistence;
    if (_initialized) return;

    // Seed default demo user: Phone: "5551234567", Password: "Password123"
    _seedDemoUser();

    if (_persistenceEnabled) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final usersJsonString = prefs.getString(_usersPrefKey);
        if (usersJsonString != null && usersJsonString.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(usersJsonString) as List<dynamic>;
          for (final item in decoded) {
            final user = User.fromJson(item as Map<String, dynamic>);
            _users[user.phone] = user;
          }
        }

        final loggedInPhone = prefs.getString(_sessionPrefKey);
        if (loggedInPhone != null && _users.containsKey(loggedInPhone)) {
          _currentUser = _users[loggedInPhone];
        }
      } catch (_) {
        // Fallback gracefully in case SharedPreferences is unavailable
      }
    }

    _initialized = true;
    userNotifier.value = _currentUser;
  }

  /// Normalizes phone string by removing spaces, parentheses, and dashes.
  static String normalizePhone(String rawPhone) {
    return rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
  }

  /// Generates a cryptographically secure random 16-byte salt in hex format.
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes the candidate password with the given salt using SHA-256.
  String hashPassword(String password, String salt) {
    final saltedBytes = utf8.encode('$salt:$password');
    return sha256.convert(saltedBytes).toString();
  }

  /// Registers a new user with role and salted SHA-256 password hash.
  Future<AuthResult> register({
    required String phone,
    required String password,
    UserRole role = UserRole.customer,
  }) async {
    final cleanPhone = normalizePhone(phone);

    if (cleanPhone.isEmpty) {
      return AuthResult.failure('Phone number is required');
    }

    if (cleanPhone.length < 10) {
      return AuthResult.failure('Phone number must contain at least 10 digits');
    }

    if (password.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters');
    }

    if (_users.containsKey(cleanPhone)) {
      return AuthResult.failure('An account is already registered with this phone number');
    }

    final salt = _generateSalt();
    final hash = hashPassword(password, salt);

    final newUser = User(
      phone: cleanPhone,
      salt: salt,
      passwordHash: hash,
      createdAt: DateTime.now(),
      role: role,
    );

    _users[cleanPhone] = newUser;
    _currentUser = newUser;
    userNotifier.value = newUser;

    await _saveToPrefs();
    if (FirestoreDataSource().isFirebaseAvailable) {
      FirestoreDataSource().saveUserProfile(newUser);
    }
    return AuthResult.success(newUser);
  }

  /// Authenticates an existing user by verifying their salted password hash.
  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = normalizePhone(phone);

    if (cleanPhone.isEmpty) {
      return AuthResult.failure('Please enter your phone number');
    }

    if (password.isEmpty) {
      return AuthResult.failure('Please enter your password');
    }

    final user = _users[cleanPhone];
    if (user == null) {
      return AuthResult.failure('No account found with this phone number. Please sign up first.');
    }

    final computedHash = hashPassword(password, user.salt);
    if (computedHash != user.passwordHash) {
      return AuthResult.failure('Incorrect password. Please check your credentials.');
    }

    _currentUser = user;
    userNotifier.value = user;
    await _saveSession(cleanPhone);
    return AuthResult.success(user);
  }

  /// Logs out current user and clears session storage.
  Future<void> logout() async {
    _currentUser = null;
    userNotifier.value = null;
    if (_persistenceEnabled) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sessionPrefKey);
      } catch (_) {}
    }
  }

  /// Helper to persist users to SharedPreferences
  Future<void> _saveToPrefs() async {
    if (!_persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersList = _users.values.map((u) => u.toJson()).toList();
      await prefs.setString(_usersPrefKey, jsonEncode(usersList));
      if (_currentUser != null) {
        await prefs.setString(_sessionPrefKey, _currentUser!.phone);
      }
    } catch (_) {}
  }

  /// Helper to persist current active session
  Future<void> _saveSession(String phone) async {
    if (!_persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionPrefKey, phone);
    } catch (_) {}
  }

  /// Switches current user role and persists changes.
  Future<void> switchRole(UserRole newRole) async {
    if (_currentUser == null) return;
    final updatedUser = _currentUser!.copyWith(role: newRole);
    _users[updatedUser.phone] = updatedUser;
    _currentUser = updatedUser;
    userNotifier.value = updatedUser;
    await _saveToPrefs();
    if (FirestoreDataSource().isFirebaseAvailable) {
      FirestoreDataSource().saveUserProfile(updatedUser);
    }
  }

  /// Updates profile details such as display name.
  Future<bool> updateProfile({String? name}) async {
    if (_currentUser == null) return false;
    final updatedUser = _currentUser!.copyWith(name: name);
    _users[updatedUser.phone] = updatedUser;
    _currentUser = updatedUser;
    userNotifier.value = updatedUser;
    await _saveToPrefs();
    if (FirestoreDataSource().isFirebaseAvailable) {
      FirestoreDataSource().saveUserProfile(updatedUser);
    }
    return true;
  }

  /// Changes current user password by verifying old password and salting the new one.
  Future<AuthResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      return AuthResult.failure('You must be logged in to change your password.');
    }
    if (newPassword.length < 6) {
      return AuthResult.failure('New password must be at least 6 characters.');
    }
    final computedOldHash = hashPassword(oldPassword, _currentUser!.salt);
    if (computedOldHash != _currentUser!.passwordHash) {
      return AuthResult.failure('Current password is incorrect.');
    }
    final newSalt = _generateSalt();
    final newHash = hashPassword(newPassword, newSalt);
    final updatedUser = _currentUser!.copyWith(
      salt: newSalt,
      passwordHash: newHash,
    );
    _users[updatedUser.phone] = updatedUser;
    _currentUser = updatedUser;
    userNotifier.value = updatedUser;
    await _saveToPrefs();
    return AuthResult.success(updatedUser);
  }

  // Active password reset tokens mapped by phone
  final Map<String, _ResetToken> _resetTokens = {};

  /// Initiates a secure password reset request with a 6-digit OTP code valid for 5 minutes.
  Future<AuthResult> requestPasswordReset(String rawPhone) async {
    final cleanPhone = normalizePhone(rawPhone);
    if (cleanPhone.isEmpty) {
      return AuthResult.failure('Please enter your phone number.');
    }
    final user = _users[cleanPhone];
    if (user == null) {
      return AuthResult.failure('No account found with this phone number. Please check and try again.');
    }

    // Generate secure 6-digit OTP
    final random = Random.secure();
    final otp = (100000 + random.nextInt(900000)).toString();
    _resetTokens[cleanPhone] = _ResetToken(
      otp: otp,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      isVerified: false,
    );

    return AuthResult.success(user);
  }

  /// Verifies the 6-digit OTP code for the given phone number.
  AuthResult verifyResetOtp(String rawPhone, String rawOtp) {
    final cleanPhone = normalizePhone(rawPhone);
    final cleanOtp = rawOtp.trim();
    final token = _resetTokens[cleanPhone];

    if (token == null || DateTime.now().isAfter(token.expiresAt)) {
      return AuthResult.failure('Verification code has expired or is invalid. Please request a new code.');
    }

    if (token.otp != cleanOtp) {
      return AuthResult.failure('Incorrect verification code. Please check and try again.');
    }

    token.isVerified = true;
    return AuthResult.success(_users[cleanPhone]!);
  }

  /// Resets password after OTP verification using a new cryptographically generated salt.
  Future<AuthResult> resetPassword({
    required String rawPhone,
    required String rawOtp,
    required String newPassword,
  }) async {
    final cleanPhone = normalizePhone(rawPhone);
    final token = _resetTokens[cleanPhone];

    if (token == null || !token.isVerified || DateTime.now().isAfter(token.expiresAt)) {
      return AuthResult.failure('Verification required before resetting password.');
    }

    if (newPassword.length < 6) {
      return AuthResult.failure('New password must be at least 6 characters.');
    }

    final user = _users[cleanPhone];
    if (user == null) {
      return AuthResult.failure('Account not found.');
    }

    final newSalt = _generateSalt();
    final newHash = hashPassword(newPassword, newSalt);
    final updatedUser = user.copyWith(
      salt: newSalt,
      passwordHash: newHash,
    );

    _users[cleanPhone] = updatedUser;
    if (_currentUser?.phone == cleanPhone) {
      _currentUser = updatedUser;
      userNotifier.value = updatedUser;
    }
    _resetTokens.remove(cleanPhone); // Invalidate token so it cannot be reused
    await _saveToPrefs();

    return AuthResult.success(updatedUser);
  }

  /// Retrieves the active OTP code for test/development purposes.
  String? getActiveOtpForTesting(String rawPhone) {
    final cleanPhone = normalizePhone(rawPhone);
    return _resetTokens[cleanPhone]?.otp;
  }

  /// Pre-seeds secure demo users for Customer and Shop Owner
  void _seedDemoUser() {
    // 1. Customer Demo
    const demoPhone = '5551234567';
    if (!_users.containsKey(demoPhone)) {
      const demoSalt = '7f8a1b2c3d4e5f60';
      final demoHash = hashPassword('Password123', demoSalt);
      _users[demoPhone] = User(
        phone: demoPhone,
        salt: demoSalt,
        passwordHash: demoHash,
        createdAt: DateTime(2026, 1, 1),
        role: UserRole.customer,
        name: 'Demo Customer',
      );
    }

    // 2. Shop Owner Demo
    const ownerPhone = '5559876543';
    if (!_users.containsKey(ownerPhone)) {
      const ownerSalt = '8a9b0c1d2e3f4a5b';
      final ownerHash = hashPassword('OwnerPass123', ownerSalt);
      _users[ownerPhone] = User(
        phone: ownerPhone,
        salt: ownerSalt,
        passwordHash: ownerHash,
        createdAt: DateTime(2026, 1, 1),
        role: UserRole.shopOwner,
        name: 'Demo Shop Owner',
      );
    }
  }

  /// Reset internal state (useful for unit tests)
  void resetForTesting({bool enablePersistence = false}) {
    _resetTokens.clear();
    _users.clear();
    _currentUser = null;
    userNotifier.value = null;
    _initialized = false;
    _persistenceEnabled = enablePersistence;
  }
}

class _ResetToken {
  final String otp;
  final DateTime expiresAt;
  bool isVerified;

  _ResetToken({
    required this.otp,
    required this.expiresAt,
    this.isVerified = false,
  });
}

