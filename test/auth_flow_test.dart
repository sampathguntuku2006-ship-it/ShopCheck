import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcheck/main.dart';
import 'package:shopcheck/screens/login_screen.dart';
import 'package:shopcheck/screens/signup_screen.dart';
import 'package:shopcheck/screens/home_screen.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AuthService().resetForTesting(enablePersistence: false);
    await AuthService().init(enablePersistence: false);
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
  });

  testWidgets('Login screen displays inputs, brand header, and validation', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: LoginScreen()));
    await tester.pumpAndSettle();

    // Verify brand title and greeting
    expect(find.text('ShopCheck'), findsOneWidget);
    expect(find.text('Sign in to check live shop hours before you travel'), findsOneWidget);

    // Verify input fields exist
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);

    // Tap Log In with empty fields -> verify validation errors
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your phone number'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('Navigation from Login to SignUp and back', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: LoginScreen()));
    await tester.pumpAndSettle();

    // Tap Sign Up link
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    // Verify SignUpScreen is displayed
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);

    // Scroll to and tap Log In to go back
    final loginLink = find.widgetWithText(TextButton, 'Log In');
    await tester.ensureVisible(loginLink);
    await tester.pumpAndSettle();
    await tester.tap(loginLink);
    await tester.pumpAndSettle();

    // Should be back at LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('SignUp validates matching passwords', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: SignUpScreen()));
    await tester.pumpAndSettle();

    // Find the 3 text fields: phone, password, confirm password
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), '5559876543');
    await tester.enterText(fields.at(1), 'Secret123');
    await tester.enterText(fields.at(2), 'DifferentPassword');
    await tester.pumpAndSettle();

    // Tap Create Account
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    // Expect "Passwords do not match" validation error
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('Successful Login navigates to HomeScreen', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: LoginScreen()));
    await tester.pumpAndSettle();

    // Use autofill or enter demo credentials
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '555-123-4567');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pumpAndSettle();

    // Tap Log In
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle();

    // Should now be on HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Nearby Shops (8)'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('Successful SignUp navigates to HomeScreen', (tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: SignUpScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '9998881122');
    await tester.enterText(fields.at(1), 'NewPassword123');
    await tester.enterText(fields.at(2), 'NewPassword123');
    await tester.pumpAndSettle();

    // Tap Create Account
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    // Should now be on HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
