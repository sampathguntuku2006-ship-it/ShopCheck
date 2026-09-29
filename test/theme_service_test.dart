import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcheck/screens/settings_screen.dart';
import 'package:shopcheck/services/theme_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService Unit Tests', () {
    test('Default theme is ThemeMode.system', () async {
      final service = ThemeService();
      await service.init();
      expect(service.themeMode, equals(ThemeMode.system));
      expect(service.isDarkMode, isFalse);
    });

    test('Switching to Dark Mode updates notifier and persists in preferences', () async {
      final service = ThemeService();
      await service.init();

      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, equals(ThemeMode.dark));
      expect(service.themeModeNotifier.value, equals(ThemeMode.dark));
      expect(service.isDarkMode, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('shopcheck_theme_mode'), equals('dark'));
    });

    test('Switching to Light Mode updates notifier and persists in preferences', () async {
      final service = ThemeService();
      await service.init();

      await service.setThemeMode(ThemeMode.light);
      expect(service.themeMode, equals(ThemeMode.light));
      expect(service.themeModeNotifier.value, equals(ThemeMode.light));
      expect(service.isDarkMode, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('shopcheck_theme_mode'), equals('light'));
    });

    test('Switching to System Default persists system mode', () async {
      final service = ThemeService();
      await service.init();

      await service.setThemeMode(ThemeMode.system);
      expect(service.themeMode, equals(ThemeMode.system));
      expect(service.themeModeNotifier.value, equals(ThemeMode.system));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('shopcheck_theme_mode'), equals('system'));
    });

    test('ThemeData properties are well-formed for Light and Dark', () {
      final light = ThemeService.lightTheme;
      final dark = ThemeService.darkTheme;

      expect(light.brightness, equals(Brightness.light));
      expect(light.colorScheme.primary, equals(const Color(0xFF16A34A)));
      expect(light.useMaterial3, isTrue);

      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.colorScheme.primary, equals(const Color(0xFF22C55E)));
      expect(dark.useMaterial3, isTrue);
    });
  });

  group('SettingsScreen Appearance Section Widget Tests', () {
    testWidgets('Settings screen renders Appearance controls and changes theme on tap', (WidgetTester tester) async {
      final themeService = ThemeService();
      await themeService.init();
      await themeService.setThemeMode(ThemeMode.system);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          home: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Appearance section title
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);

      // Tap on "Dark" radio tile
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(themeService.themeMode, equals(ThemeMode.dark));

      // Tap on "Light" radio tile
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeService.themeMode, equals(ThemeMode.light));
    });
  });
}
