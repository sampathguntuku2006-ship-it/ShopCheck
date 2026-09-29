import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/models/user.dart';
import 'package:shopcheck/screens/chat_screen.dart';
import 'package:shopcheck/services/ai_service.dart';
import 'package:shopcheck/services/auth_service.dart';
import 'package:shopcheck/services/database_service.dart';
import 'package:shopcheck/services/location_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
    AuthService().resetForTesting();
    await AuthService().init();
    LocationService().resetForTesting();
    AiService().clearConversation();
  });

  group('AiService Grounded Shop Information Tests', () {
    test('Querying an existing shop returns verified live details with action buttons', () async {
      final ai = AiService();
      await ai.sendMessage('Is Sri Krishna Supermarket open right now?');

      expect(ai.messages.length, greaterThanOrEqualTo(2));
      final aiReply = ai.messages.last;

      expect(aiReply.isUser, isFalse);
      expect(aiReply.text, contains('Sri Krishna Supermarket'));
      expect(aiReply.text, contains('Banjara Hills'));
      expect(aiReply.text, contains('+91 98490 12345'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.viewShop), isTrue);
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.getDirections), isTrue);
    });

    test('Querying an unknown shop returns strict "I don\'t have that information" (no hallucinations)', () async {
      final ai = AiService();
      await ai.sendMessage('Is Walmart Supercenter open?');

      final aiReply = ai.messages.last;
      expect(aiReply.isUser, isFalse);
      expect(aiReply.text, contains("I don't have that information for this shop."));
      expect(aiReply.text, isNot(contains('Closes at')));
      expect(aiReply.text, isNot(contains('Opens at')));
    });

    test('Querying another unregistered shop does not hallucinate hours', () async {
      final ai = AiService();
      await ai.sendMessage('What time does Target store close?');

      final aiReply = ai.messages.last;
      expect(aiReply.isUser, isFalse);
      expect(aiReply.text, contains("I don't have that information for this shop."));
    });
  });

  group('AiService Category & Nearby Queries', () {
    test('Asking for pharmacies lists pharmacy shops with category and address', () async {
      final ai = AiService();
      await ai.sendMessage('Are there any pharmacies open near me?');

      final aiReply = ai.messages.last;
      expect(aiReply.isUser, isFalse);
      expect(aiReply.text.toLowerCase(), contains('pharmacy'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.openMap), isTrue);
    });

    test('Asking for grocery stores lists grocery shops', () async {
      final ai = AiService();
      await ai.sendMessage('Find grocery stores');

      final aiReply = ai.messages.last;
      expect(aiReply.isUser, isFalse);
      expect(aiReply.text.toLowerCase(), contains('grocery'));
    });

    test('Asking for closing soon shops returns calculated status', () async {
      final ai = AiService();
      await ai.sendMessage('Which shops are closing soon?');

      final aiReply = ai.messages.last;
      expect(aiReply.isUser, isFalse);
      expect(aiReply.text, isNotEmpty);
    });
  });

  group('AiService Role-Aware Logic', () {
    test('Customer asking to add a shop is advised to switch role with action button', () async {
      await AuthService().register(
        phone: '9876543210',
        password: 'Password123',
        role: UserRole.customer,
      );

      final ai = AiService();
      await ai.sendMessage('How do I add a new shop?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Shop Owner'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.switchRole), isTrue);
    });

    test('Shop owner asking to add a shop gets owner creation instructions', () async {
      await AuthService().register(
        phone: '9876543211',
        password: 'Password123',
        role: UserRole.shopOwner,
      );

      final ai = AiService();
      await ai.sendMessage('How do I add a new shop?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Add Shop'));
      expect(aiReply.text, contains('PIN code'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.addShop), isTrue);
    });

    test('Shop owner asking to temporarily close shop gets temporary closure instructions', () async {
      await AuthService().register(
        phone: '9876543212',
        password: 'Password123',
        role: UserRole.shopOwner,
      );

      final ai = AiService();
      await ai.sendMessage('How do I temporarily close my shop?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Temporarily Close Shop'));
      expect(aiReply.text, contains('TEMPORARILY CLOSED'));
      expect(aiReply.text, contains('Reopen Shop'));
    });
  });

  group('AiService App Usage & Feature Assistance', () {
    test('Dark mode assistance mentions Settings and provides Open Settings action', () async {
      final ai = AiService();
      await ai.sendMessage('How do I use dark mode?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Appearance'));
      expect(aiReply.text, contains('Dark'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.openSettings), isTrue);
    });

    test('Password reset assistance mentions OTP and provides Help & Support action', () async {
      final ai = AiService();
      await ai.sendMessage('How do I reset my password?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Forgot Password'));
      expect(aiReply.text, contains('OTP'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.openHelp), isTrue);
    });

    test('Directions and Maps assistance provides Open Map action', () async {
      final ai = AiService();
      await ai.sendMessage('How do I get directions to a shop?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Directions'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.openMap), isTrue);
    });

    test('Favorites assistance provides View Favorites action', () async {
      final ai = AiService();
      await ai.sendMessage('How do I add favorites?');

      final aiReply = ai.messages.last;
      expect(aiReply.text, contains('Favorites'));
      expect(aiReply.actions.any((a) => a.type == ChatActionButtonType.openFavorites), isTrue);
    });

    test('Clearing conversation restores initial welcome message', () {
      final ai = AiService();
      ai.sendMessage('Hello');
      expect(ai.messages.length, greaterThan(1));

      ai.clearConversation();
      expect(ai.messages.length, equals(1));
      expect(ai.messages.first.id, equals('welcome_msg'));
    });
  });

  group('ChatScreen Widget Tests', () {
    testWidgets('ChatScreen renders header, initial prompt, suggestion chips, and input bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify AppBar Title
      expect(find.text('ShopCheck AI'), findsOneWidget);

      // Verify Welcome message
      expect(find.textContaining("Hi! I'm your ShopCheck assistant"), findsOneWidget);

      // Verify Suggestion chips
      expect(find.text('Which shops are open near me?'), findsOneWidget);

      // Verify Input text field
      expect(find.text('Ask me anything about ShopCheck...'), findsOneWidget);

      // Verify Send button
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('Sending a message via TextField adds user bubble and AI bubble', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'How do I use dark mode?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('How do I use dark mode?'), findsWidgets);
      expect(find.textContaining('Appearance'), findsWidgets);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('Tapping a suggestion chip sends the prompt immediately', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Which shops are open near me?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Which shops are open near me?'), findsWidgets);
      expect(find.textContaining('shops in ShopCheck'), findsWidgets);
    });
  });
}
