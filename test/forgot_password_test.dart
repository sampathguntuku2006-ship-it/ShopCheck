import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/models/user.dart';
import 'package:shopcheck/screens/forgot_password_screen.dart';
import 'package:shopcheck/services/auth_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().resetForTesting();
    await AuthService().init();
  });

  group('AuthService Forgot Password & OTP Reset Logic', () {
    test('Requesting password reset for unregistered phone returns failure', () async {
      final res = await AuthService().requestPasswordReset('9999999999');
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('No account found'));
    });

    test('Full password reset flow with valid OTP updates password and allows login', () async {
      // 1. Register a user
      final signupRes = await AuthService().register(
        phone: '9876543210',
        password: 'OriginalPass123',
        role: UserRole.customer,
      );
      expect(signupRes.isSuccess, isTrue);

      // 2. Request password reset
      final reqRes = await AuthService().requestPasswordReset('9876543210');
      expect(reqRes.isSuccess, isTrue);
      final demoOtp = AuthService().getActiveOtpForTesting('9876543210');
      expect(demoOtp, isNotNull);
      expect(demoOtp!.length, equals(6));

      // 3. Verify OTP with wrong code fails
      final wrongOtpRes = AuthService().verifyResetOtp('9876543210', '000000');
      expect(wrongOtpRes.isSuccess, isFalse);

      // 4. Verify OTP with correct code succeeds
      final verifyRes = AuthService().verifyResetOtp('9876543210', demoOtp);
      expect(verifyRes.isSuccess, isTrue);

      // 5. Reset password with new password
      final resetRes = await AuthService().resetPassword(
        rawPhone: '9876543210',
        rawOtp: demoOtp,
        newPassword: 'NewStrongPass789',
      );
      expect(resetRes.isSuccess, isTrue);

      // 6. Old password login must fail
      final oldLoginRes = await AuthService().login(
        phone: '9876543210',
        password: 'OriginalPass123',
      );
      expect(oldLoginRes.isSuccess, isFalse);

      // 7. New password login must succeed
      final newLoginRes = await AuthService().login(
        phone: '9876543210',
        password: 'NewStrongPass789',
      );
      expect(newLoginRes.isSuccess, isTrue);
      expect(AuthService().isAuthenticated, isTrue);
      expect(AuthService().currentUser?.phone, equals('9876543210'));
    });

    test('Reset OTP cannot be reused after successful password reset', () async {
      await AuthService().register(
        phone: '9849012345',
        password: 'PasswordOne1',
        role: UserRole.shopOwner,
      );

      final reqRes = await AuthService().requestPasswordReset('9849012345');
      expect(reqRes.isSuccess, isTrue);
      final otp = AuthService().getActiveOtpForTesting('9849012345');
      expect(otp, isNotNull);

      final verifyRes = AuthService().verifyResetOtp('9849012345', otp!);
      expect(verifyRes.isSuccess, isTrue);

      final reset1 = await AuthService().resetPassword(
        rawPhone: '9849012345',
        rawOtp: otp,
        newPassword: 'PasswordTwo2',
      );
      expect(reset1.isSuccess, isTrue);

      // Second attempt with same OTP must fail
      final reset2 = await AuthService().resetPassword(
        rawPhone: '9849012345',
        rawOtp: otp,
        newPassword: 'PasswordThree3',
      );
      expect(reset2.isSuccess, isFalse);
    });
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('ForgotPasswordScreen navigates through phone, OTP, new password, and success', (WidgetTester tester) async {
      await AuthService().register(
        phone: '9123456780',
        password: 'InitialPassword1',
        role: UserRole.customer,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Phone number entry
      expect(find.text('Reset Password'), findsWidgets);
      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '9123456780');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: OTP verification step
      expect(find.text('Verify Code'), findsOneWidget);
      final otp = AuthService().getActiveOtpForTesting('9123456780');
      expect(otp, isNotNull);

      await tester.enterText(find.byType(TextField).first, otp!);
      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle();

      // Step 3: New Password step
      expect(find.text('New Password'), findsOneWidget);
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'BrandNewPass123');
      await tester.enterText(textFields.at(1), 'BrandNewPass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();

      // Step 4: Success screen
      expect(find.text('Password reset successfully.'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });
  });
}
