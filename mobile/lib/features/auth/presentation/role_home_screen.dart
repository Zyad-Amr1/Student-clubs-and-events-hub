import 'package:campusconnect/features/clubs/presentation/club_head_screen.dart';
import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/portal_role.dart';
import 'package:campusconnect/features/auth/presentation/account_screens.dart';
import 'package:campusconnect/features/clubs/presentation/club_management_form.dart';
import 'package:campusconnect/features/clubs/presentation/club_requests_screen.dart';
import 'package:campusconnect/features/clubs/presentation/membership_screen.dart';
import 'package:campusconnect/features/clubs/presentation/interview_screens.dart';
import 'package:campusconnect/features/clubs/presentation/club_lifecycle_screen.dart';
import 'package:campusconnect/features/events/presentation/create_event_screen.dart';
import 'package:campusconnect/features/events/presentation/review_events_screen.dart';
import 'package:material_ui/material_ui.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({required this.portal, super.key});

  final PortalRole portal;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  bool _checking = false;
  String? _error;

  Future<void> _refresh() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final session = StudentSessionScope.of(context);
    try {
      await session.refreshPortalAccess();
    } on ApiFailure catch (error) {
      if (!mounted) return;
      if (!session.signedIn) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
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
    final session = StudentSessionScope.of(context);
    if (!session.signedIn ||
        session.portal != widget.portal ||
        widget.portal == PortalRole.student) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: Center(
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
            child: const Text('Return to portal selection'),
          ),
        ),
      );
    }

    final admin = widget.portal == PortalRole.clubAdmin;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.portal.label} portal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CampusHeader(
              session.profile?.fullName ?? '',
              admin
                  ? 'Manage your assigned clubs and their events.'
                  : 'Student Affairs access verified',
              icon: admin
                  ? Icons.groups_outlined
                  : Icons.verified_user_outlined,
            ),
            const SizedBox(height: 12),
            if (admin) ...[
              OutlinedButton.icon(
                onPressed: _checking
                    ? null
                    : () async {
                        setState(() => _checking = true);
                        try {
                          await session.switchStudentMode(PortalRole.student);
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.home,
                              (_) => false,
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () =>
                                  _error = 'Could not switch to Student Mode.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _checking = false);
                        }
                      },
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Switch Back to Student Mode'),
              ),
              const CampusSectionHeader(title: 'Clubs you administer'),
              if (session.managedClubs.isEmpty)
                const CampusFeedback('No clubs are assigned to this account.'),
              for (final club in session.managedClubs)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: ValueKey('managed-club-${club.id}'),
                        leading: const CampusIconTile(Icons.groups_outlined),
                        title: Text(club.name),
                        subtitle: Text(
                          club.isActive
                              ? 'Create and submit events for review'
                              : 'Archived: ${club.archiveReason ?? 'No reason recorded'}',
                        ),
                        trailing: club.isActive
                            ? const Icon(Icons.chevron_right)
                            : const Icon(Icons.archive_outlined),
                        onTap: club.isActive
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CreateEventScreen(club: club),
                                ),
                              )
                            : null,
                      ),
                      if (club.isActive) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _PortalAction(
                          'Edit Club Profile',
                          Icons.edit_outlined,
                          (_) => ManagedClubProfileScreen(club.id),
                        ),
                        _PortalAction(
                          'Membership Applications',
                          Icons.assignment_outlined,
                          (_) => MembershipScreen(club: club),
                        ),
                        _PortalAction(
                          'Interview Days',
                          Icons.event_available_outlined,
                          (_) => AdminInterviewDaysScreen(club),
                        ),
                      ],
                    ],
                  ),
                ),
            ] else ...[
              const CampusSectionHeader(title: 'Review and manage'),
              Card(
                child: Column(
                  children: [
                    _PortalAction(
                      'Review pending events',
                      Icons.fact_check_outlined,
                      (_) => const ReviewEventsScreen(),
                      key: const ValueKey('open-pending-review'),
                    ),
                    _PortalAction(
                      'Review Club Requests',
                      Icons.assignment_outlined,
                      (_) => const ClubRequestsScreen(review: true),
                    ),
                    _PortalAction(
                      'Review Club Head Requests',
                      Icons.badge_outlined,
                      (_) => const ClubHeadScreen(review: true),
                    ),
                    _PortalAction(
                      'Manage Club Lifecycle',
                      Icons.groups_outlined,
                      (_) => const ClubLifecycleScreen(),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              CampusFeedback(_error!, icon: Icons.error_outline),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const ValueKey('refresh-portal-access'),
              onPressed: _checking ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(_checking ? 'Checking...' : 'Recheck permissions'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              ),
              child: const Text('Account Settings'),
            ),
            FilledButton.icon(
              key: const ValueKey('role-logout'),
              onPressed: _checking ? null : _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalAction extends StatelessWidget {
  const _PortalAction(this.label, this.icon, this.destination, {super.key});

  final String label;
  final IconData icon;
  final WidgetBuilder destination;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CampusIconTile(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: destination)),
  );
}
