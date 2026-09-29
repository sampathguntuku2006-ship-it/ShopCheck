import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcheck/main.dart';
import 'package:shopcheck/screens/home_screen.dart';
import 'package:shopcheck/screens/shop_details_screen.dart';
import 'package:shopcheck/services/database_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    DatabaseService().resetForTesting();
    await DatabaseService().init(enablePersistence: false);
  });

  testWidgets('ShopCheck renders home screen with title, search bar, and shops', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify App Title
    expect(find.text('ShopCheck'), findsOneWidget);

    // Verify Search Bar hint
    expect(find.text('Search shops by name...'), findsOneWidget);

    // Verify Sample Shops are displayed
    expect(find.text('Sri Krishna Supermarket'), findsOneWidget);
    expect(find.text('Third Wave Coffee Roasters'), findsOneWidget);

    // Verify presence of OPEN or CLOSED badges
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data == 'OPEN' || widget.data == 'CLOSED'),
      ),
      findsWidgets,
    );
  });

  testWidgets('Searching shops by name filters the list', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Type "Bakery" into the search bar
    await tester.enterText(find.byType(TextField), 'Bakery');
    await tester.pumpAndSettle();

    // Karachi Bakery & Confectionery should be visible
    expect(find.text('Karachi Bakery & Confectionery'), findsOneWidget);

    // Other shops like Third Wave Coffee Roasters should be filtered out
    expect(find.text('Third Wave Coffee Roasters'), findsNothing);

    // Clear search by tapping the clear button
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    // Both shops should be back
    expect(find.text('Sri Krishna Supermarket'), findsOneWidget);
    expect(find.text('Third Wave Coffee Roasters'), findsOneWidget);
  });

  testWidgets('Tapping a shop card navigates to the shop details screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopCheckApp(initialHome: HomeScreen()));
    await tester.pumpAndSettle();

    // Tap on Sri Krishna Supermarket
    await tester.tap(find.text('Sri Krishna Supermarket'));
    await tester.pumpAndSettle();

    // Verify ShopDetailsScreen is open
    expect(find.byType(ShopDetailsScreen), findsOneWidget);

    // Verify details fields: Address, Phone, Opening Hours
    expect(find.text('Road No. 10, Banjara Hills, Hyderabad, Telangana - 500034'), findsOneWidget);
    expect(find.text('+91 98490 12345'), findsOneWidget);
    expect(find.text('Weekly Opening Hours'), findsOneWidget);
    expect(find.text('Location & Contact'), findsOneWidget);
  });
}

