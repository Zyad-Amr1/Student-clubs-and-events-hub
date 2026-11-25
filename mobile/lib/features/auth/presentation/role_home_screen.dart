import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/portal_role.dart';
import 'package:campusconnect/features/auth/presentation/account_screens.dart';
import 'package:campusconnect/features/clubs/presentation/club_management_form.dart';
import 'package:campusconnect/features/clubs/presentation/club_requests_screen.dart';
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
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              session.profile?.fullName ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              admin ? 'Your assigned clubs are verified by CampusConnect.' : 'Your Student Affairs account has been verified by CampusConnect.',
            ),
            const SizedBox(height: 20),
            if (admin) ...[
              TextButton(
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
                child: const Text('Switch Back to Student Mode'),
              ),
              Text(
                'Clubs you administer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              for (final club in session.managedClubs)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: ValueKey('managed-club-${club.id}'),
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(club.name),
                        subtitle: const Text(
                          'Create and submit events for review',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CreateEventScreen(club: club),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => ManagedClubProfileScreen(club.id),
                          ),
                        ),
                        child: const Text('Edit Club Profile'),
                      ),
                    ],
                  ),
                ),
            ] else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Student Affairs access verified'),
                  subtitle: Text('Review submitted events for publication'),
                ),
              ),
            if (!admin) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('open-pending-review'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReviewEventsScreen(),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review pending events'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ClubRequestsScreen(review: true),
                  ),
                ),
                child: const Text('Review Club Requests'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
