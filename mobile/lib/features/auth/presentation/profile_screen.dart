import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/portal_role.dart';
import 'package:campusconnect/features/auth/presentation/account_screens.dart';
import 'package:campusconnect/features/clubs/presentation/club_requests_screen.dart';
import 'package:campusconnect/features/clubs/presentation/membership_screen.dart';
import 'package:campusconnect/features/clubs/presentation/club_lifecycle_screen.dart';
import 'package:campusconnect/shared/widgets/pick_image.dart';
import 'package:material_ui/material_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;
  bool _hasClub = false;
  bool _switching = false;
  String? _clubError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkClubs();
    });
  }

  Future<void> _checkClubs() async {
    final session = StudentSessionScope.of(context);
    if (session.profile?.accountType != 'student') return;
    try {
      final clubs = await session.authenticated(session.api.myManagedClubs);
      if (mounted) {
        setState(() {
          _hasClub = clubs.isNotEmpty;
          _clubError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasClub = false);
    }
  }

  Future<void> _manage() async {
    setState(() {
      _switching = true;
      _clubError = null;
    });
    try {
      await StudentSessionScope.of(context)
          .switchStudentMode(PortalRole.clubAdmin);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _clubError = error.message);
      if (mounted) await _checkClubs();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    String? warning;
    try {
      await StudentSessionScope.of(context).logout();
    } on ApiFailure catch (error) {
      warning = error.message;
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning)));
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
            Center(child: UploadedImage(user.picture)),
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
            if (user.accountType == 'student') ...[
              Text(_hasClub ? 'Student · Club Admin' : 'Student'),
              if (user.faculty != null) Text('Faculty · ${user.faculty}'),
              if (user.department != null)
                Text('Department · ${user.department}'),
              if (user.academicYear != null)
                Text('Academic year · ${user.academicYear}'),
              ListTile(
                title: const Text('Edit Profile'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditProfileScreen(user),
                  ),
                ),
              ),
              if (_hasClub)
                ListTile(
                  title: const Text('Manage My Club'),
                  onTap: _switching ? null : _manage,
                ),
              if (_clubError != null) Text(_clubError!),
            ],
            ListTile(
              title: const Text('Account Settings'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              ),
            ),
            if (user.accountType == 'student') ...[
              ListTile(
                title: const Text('My Club Requests'),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClubRequestsScreen(),
                    ),
                  );
                  if (mounted) await _checkClubs();
                },
              ),
              ListTile(
                title: const Text('My Clubs'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MembershipScreen(memberships: true),
                  ),
                ),
              ),
              ListTile(
                title: const Text('My Applications'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MembershipScreen(),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Club Notifications'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ClubLifecycleScreen(studentNotices: true),
                  ),
                ),
              ),
            ],
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
