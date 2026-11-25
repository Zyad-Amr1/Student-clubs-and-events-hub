import 'package:campusconnect/features/clubs/presentation/club_head_screen.dart';
import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/portal_role.dart';
import 'package:campusconnect/features/auth/presentation/account_screens.dart';
import 'package:campusconnect/features/clubs/presentation/club_requests_screen.dart';
import 'package:campusconnect/features/clubs/presentation/membership_screen.dart';
import 'package:campusconnect/features/clubs/presentation/club_lifecycle_screen.dart';
import 'package:campusconnect/features/events/presentation/my_events_screen.dart';
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
    final campusDetails = [
      if (user.department != null) user.department!,
      if (user.faculty != null) user.faculty!,
      if (user.academicYear != null) 'Year ${user.academicYear}',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Account settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccountSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                child: Column(
                  children: [
                    Container(
                      width: 94,
                      height: 94,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: CampusColors.gradient,
                      ),
                      child: ClipOval(
                        child: ColoredBox(
                          color: CampusColors.lavender,
                          child: UploadedImage(user.picture, size: 88),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName,
                      key: const ValueKey('profile-name'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (campusDetails.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        campusDetails,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 10),
                    CampusStatus(
                      user.accountType == 'student'
                          ? (_hasClub ? 'Student · Club Admin' : 'Student')
                          : user.accountType,
                    ),
                    if (_hasClub) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _switching ? null : _manage,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Manage My Club'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (user.accountType == 'student') ...[
              const SizedBox(height: 14),
              const CampusSectionHeader(title: 'Your campus activity'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.confirmation_num_outlined),
                      title: const Text('My Bookings'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyEventsScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: const Text('My Club Requests'),
                      trailing: const Icon(Icons.chevron_right_rounded),
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
                      leading: const Icon(Icons.groups_outlined),
                      title: const Text('My Clubs'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const MembershipScreen(memberships: true),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: const Text('My Applications'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MembershipScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('My Club Head Requests'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ClubHeadScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Club Notifications'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const ClubLifecycleScreen(studentNotices: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_clubError != null) ...[
                const SizedBox(height: 8),
                CampusFeedback(_clubError!, icon: Icons.error_outline),
              ],
            ],
            const SizedBox(height: 14),
            const CampusSectionHeader(title: 'Account details'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('University ID'),
                    subtitle: Text(user.universityId),
                  ),
                  if (user.accountType == 'student')
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EditProfileScreen(user),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
