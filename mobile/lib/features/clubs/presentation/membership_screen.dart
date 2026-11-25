import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/clubs/presentation/interview_screens.dart';
import 'package:material_ui/material_ui.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({this.club, this.memberships = false, super.key});
  final ManagedClub? club;
  final bool memberships;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final _items = <MembershipApplication>[];
  bool _busy = false;
  bool _more = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    final session = StudentSessionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await session.authenticated(
        (token) => session.api.applications(
          token,
          clubId: widget.club?.id,
          memberships: widget.memberships,
          page: reset ? 1 : _page,
        ),
      );
      if (!mounted) return;
      if (reset) {
        _page = 1;
        _items.clear();
      }
      _items.addAll(data.items);
      _page++;
      _more = data.more;
    } on ApiFailure catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(
    MembershipApplication application,
    String decision,
  ) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm application decision'),
        content: Text(
          decision == 'accepted'
              ? 'Accept ${application.applicantName} as a member?'
              : 'Require an interview for ${application.applicantName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    final session = StudentSessionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    var saved = false;
    try {
      await session.authenticated(
        (token) => session.api.reviewApplication(
          token,
          widget.club!.id,
          application.id,
          decision,
        ),
      );
      saved = true;
    } on ApiFailure catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && saved) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.club != null;
    final signedIn = StudentSessionScope.of(context).signedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          admin
              ? 'Membership Applications'
              : widget.memberships
              ? 'My Clubs'
              : 'My Applications',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: _busy || !signedIn ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!signedIn)
              const Text('Sign in again to see applications.')
            else ...[
              if (admin)
                CampusHeader(
                  widget.club!.name,
                  'Review applications and decide which students need an interview.',
                  icon: Icons.assignment_outlined,
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                CampusFeedback(
                  _error!,
                  icon: Icons.error_outline,
                  retry: _busy ? null : () => _load(reset: true),
                )
              else if (!_busy && _items.isEmpty)
                CampusFeedback(
                  widget.memberships
                      ? 'You have no accepted memberships yet.'
                      : 'No applications yet.',
                  icon: Icons.inbox_outlined,
                ),
              for (final application in _items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin
                              ? application.applicantName
                              : application.clubName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: CampusStatus(application.statusLabel),
                        ),
                        if (!admin &&
                            application.status == 'interview_required')
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    StudentInterviewScreen(application),
                              ),
                            ),
                            child: const Text('Manage interview'),
                          ),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(application.submittedAt.toLocal()),
                        ),
                        if (admin && application.status == 'pending')
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _review(
                                        application,
                                        'interview_required',
                                      ),
                                child: const Text('Require interview'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _review(application, 'accepted'),
                                child: const Text('Accept membership'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              if (_more)
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Load more'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
