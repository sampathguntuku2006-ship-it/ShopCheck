import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'customer_shell.dart';
import 'login_screen.dart';
import 'owner_shell.dart';

/// Root navigation shell that dynamically rebuilds whenever the user role
/// or authentication state changes, ensuring immediate UI reactivity.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: AuthService().userNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const LoginScreen();
        }

        if (user.role == UserRole.shopOwner) {
          return const OwnerShell(key: ValueKey('owner_shell'));
        }

        return const CustomerShell(key: ValueKey('customer_shell'));
      },
    );
  }
}
