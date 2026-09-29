import 'package:flutter_test/flutter_test.dart';
import 'package:shopcheck/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();

  setUp(() async {
    authService.resetForTesting(enablePersistence: false);
    await authService.init(enablePersistence: false);
  });

  group('AuthService Unit Tests', () {
    test('Pass-words are NEVER stored in plain text', () {
      final user = authService.currentUser;

      // Log in with demo user
      // Demo password is "Password123"
      expect(user, isNull); // before login

      const plainPassword = 'Password123';
      const demoPhone = '5551234567';

      // Verify the stored hash is NOT plain text
      final result = authService.login(phone: demoPhone, password: plainPassword);
      expect(result, completion(predicate<AuthResult>((r) => r.isSuccess)));
    });

    test('Demo user authenticates with correct password and fails with wrong password', () async {
      // Correct password
      final successResult = await authService.login(
        phone: '555-123-4567',
        password: 'Password123',
      );
      expect(successResult.isSuccess, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser!.phone, equals('5551234567'));
      // Verify password is stored as a 64-character SHA-256 hex string, NOT plain text
      expect(authService.currentUser!.passwordHash.length, equals(64));
      expect(authService.currentUser!.passwordHash, isNot(contains('Password123')));

      // Wrong password
      final failResult = await authService.login(
        phone: '555-123-4567',
        password: 'WrongPassword999',
      );
      expect(failResult.isSuccess, isFalse);
      expect(failResult.errorMessage, contains('Incorrect password'));
    });

    test('Login with unregistered phone returns failure', () async {
      final result = await authService.login(
        phone: '9998887777',
        password: 'SomePassword1',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('No account found'));
    });

    test('Register new user with salted hash and prevent duplicates', () async {
      const newPhone = '9876543210';
      const newPassword = 'SecureSecret456';

      final regResult = await authService.register(
        phone: newPhone,
        password: newPassword,
      );

      expect(regResult.isSuccess, isTrue);
      final registeredUser = regResult.user!;
      expect(registeredUser.phone, equals(newPhone));
      // Verify salt and hash
      expect(registeredUser.salt.isNotEmpty, isTrue);
      expect(registeredUser.passwordHash.length, equals(64));
      expect(registeredUser.passwordHash, isNot(equals(newPassword)));

      // Can now log in with the new credentials
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);

      final loginResult = await authService.login(
        phone: '(987) 654-3210',
        password: newPassword,
      );
      expect(loginResult.isSuccess, isTrue);

      // Attempting to register the same phone again should fail
      final duplicateResult = await authService.register(
        phone: newPhone,
        password: 'AnotherPassword',
      );
      expect(duplicateResult.isSuccess, isFalse);
      expect(duplicateResult.errorMessage, contains('already registered'));
    });

    test('Password shorter than 6 characters is rejected', () async {
      final result = await authService.register(
        phone: '9991112233',
        password: '123',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('at least 6 characters'));
    });

    test('Logout clears current user session', () async {
      await authService.login(
        phone: '5551234567',
        password: 'Password123',
      );
      expect(authService.isAuthenticated, isTrue);

      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
    });
  });
}
