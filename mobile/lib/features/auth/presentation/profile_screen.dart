import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:material_ui/material_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await StudentSessionScope.of(context).logout();
    } finally {
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = StudentSessionScope.of(context).profile;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.authentication,
              (route) => false,
            ),
            child: const Text('Sign in'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Student profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.account_circle_outlined, size: 72),
            const SizedBox(height: 16),
            Text(
              user.fullName,
              key: const ValueKey('profile-name'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email'),
              subtitle: Text(user.email),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('University ID'),
              subtitle: Text(user.universityId),
            ),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              key: const ValueKey('profile-logout'),
              onPressed: _loggingOut ? null : _logout,
              icon: const Icon(Icons.logout_rounded),
              label: Text(_loggingOut ? 'Signing out...' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
