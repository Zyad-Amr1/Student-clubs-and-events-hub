import 'dart:async';

import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/app/theme.dart';
import 'package:campusconnect/app/welcome_screen.dart';
import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:campusconnect/features/auth/presentation/auth_screen.dart';
import 'package:campusconnect/features/auth/presentation/profile_screen.dart';
import 'package:campusconnect/features/clubs/presentation/clubs_screen.dart';
import 'package:material_ui/material_ui.dart';

class CampusConnectApp extends StatefulWidget {
  const CampusConnectApp({super.key, this.authController});

  final AuthController? authController;

  @override
  State<CampusConnectApp> createState() => _CampusConnectAppState();
}

class _CampusConnectAppState extends State<CampusConnectApp> {
  late final AuthController _authController =
      widget.authController ?? AuthController.production();

  @override
  void initState() {
    super.initState();
    unawaited(_authController.initialize());
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusConnect',
      debugShowCheckedModeBanner: false,
      theme: CampusConnectTheme.light,
      home: _AuthGate(controller: _authController),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.authentication) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AuthScreen(controller: _authController),
          );
        }
        if (settings.name == AppRoutes.clubs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _authController.isAuthenticated
                ? ClubsScreen(controller: _authController)
                : AuthScreen(controller: _authController),
          );
        }
        if (settings.name == AppRoutes.profile) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _authController.isAuthenticated
                ? ProfileScreen(controller: _authController)
                : AuthScreen(controller: _authController),
          );
        }
        if (settings.name == AppRoutes.home) return null;
        return null;
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.isAuthenticated) {
          return ClubsScreen(controller: controller);
        }
        return WelcomeScreen(restoreError: controller.restoreError);
      },
    );
  }
}
