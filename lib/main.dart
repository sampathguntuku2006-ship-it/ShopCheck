import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice (running in local offline cache mode): $e');
  }
  await AuthService().init();
  await DatabaseService().init();
  await ThemeService().init();
  runApp(const ShopCheckApp());
}

class ShopCheckApp extends StatelessWidget {
  final Widget? initialHome;

  const ShopCheckApp({super.key, this.initialHome});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'ShopCheck',
          debugShowCheckedModeBanner: false,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: themeMode,
          home: initialHome ??
              (AuthService().isAuthenticated
                  ? const AppShell()
                  : const LoginScreen()),
        );
      },
    );
  }
}
