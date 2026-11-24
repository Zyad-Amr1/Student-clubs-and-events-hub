import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/app/theme.dart';
import 'package:campusconnect/app/welcome_screen.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:campusconnect/features/auth/presentation/auth_screen.dart';
import 'package:campusconnect/features/auth/presentation/profile_screen.dart';
import 'package:campusconnect/features/clubs/presentation/clubs_screen.dart';
import 'package:flutter/material.dart';

class StudentSessionScope extends InheritedNotifier<StudentSession> {
  const StudentSessionScope({
    required StudentSession session,
    required super.child,
    super.key,
  }) : super(notifier: session);

  static StudentSession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<StudentSessionScope>();
    assert(scope != null, 'Missing StudentSessionScope');
    return scope!.notifier!;
  }
}

class CampusConnectApp extends StatefulWidget {
  const CampusConnectApp({super.key, this.api, this.tokenStore});

  final CampusApi? api;
  final TokenStore? tokenStore;

  @override
  State<CampusConnectApp> createState() => _CampusConnectAppState();
}

class _CampusConnectAppState extends State<CampusConnectApp> {
  late final StudentSession _session;

  @override
  void initState() {
    super.initState();
    _session = StudentSession(
      api: widget.api ?? CampusApi(),
      store: widget.tokenStore ?? const AndroidKeystoreTokenStore(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.restore();
    });
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CampusConnect',
    debugShowCheckedModeBanner: false,
    theme: CampusConnectTheme.light,
    builder: (context, child) => StudentSessionScope(
      session: _session,
      child: child ?? const SizedBox.shrink(),
    ),
    initialRoute: AppRoutes.home,
    routes: {
      AppRoutes.home: (context) => const _HomeGate(),
      AppRoutes.authentication: (context) => const AuthScreen(),
      AppRoutes.clubs: (context) => const ClubsScreen(),
      AppRoutes.profile: (context) => const ProfileScreen(),
    },
  );
}

class _HomeGate extends StatelessWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context) {
    final session = StudentSessionScope.of(context);
    if (!session.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.restoreError != null && !session.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('CampusConnect')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(session.restoreError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: session.restore,
                  child: const Text('Retry session'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return session.signedIn ? const ClubsScreen() : const WelcomeScreen();
  }
}
