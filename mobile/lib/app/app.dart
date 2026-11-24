import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/app/theme.dart';
import 'package:campusconnect/app/welcome_screen.dart';
import 'package:campusconnect/features/auth/presentation/auth_placeholder_screen.dart';
import 'package:campusconnect/features/clubs/presentation/clubs_placeholder_screen.dart';
import 'package:material_ui/material_ui.dart';

class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusConnect',
      debugShowCheckedModeBanner: false,
      theme: CampusConnectTheme.light,
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (context) => const WelcomeScreen(),
        AppRoutes.authentication: (context) => const AuthPlaceholderScreen(),
        AppRoutes.clubs: (context) => const ClubsPlaceholderScreen(),
      },
    );
  }
}
