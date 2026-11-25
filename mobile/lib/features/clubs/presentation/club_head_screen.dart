import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

class ClubHeadScreen extends StatefulWidget {
  const ClubHeadScreen({this.club, this.review = false, super.key});

  final CampusClub? club;
  final bool review;

  @override
  State<ClubHeadScreen> createState() => _ClubHeadScreenState();
}

class _ClubHeadScreenState extends State<ClubHeadScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _availability;
  List<JsonObject> _requests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = StudentSessionScope.of(context);
    try {
      final club = widget.club;
      final availability = club == null
          ? null
          : await session.authenticated(
              (token) => session.api.headVacancy(token, club.id),
            );
      final requests = await session.authenticated(
        (token) => session.api.headRequests(token, review: widget.review),
      );
      if (!mounted) return;
      _availability = availability;
      _requests = club == null
          ? requests
          : requests.where((row) => row['club_id'] == club.id).toList();
    } on ApiFailure catch (error) {
      if (mounted) _error = error.message;
    } on Object {
      if (mounted) _error = 'Could not load Club Head requests.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(
    Future<void> Function(CampusApi, String) action,
    String success,
  ) async {
    setState(() => _submitting = true);
    final session = StudentSessionScope.of(context);
    try {
      await session.authenticated((token) => action(session.api, token));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) await _load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _apply(CampusClub club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Club Head request?'),
        content: Text(
          'Student Affairs will review your application for ${club.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _submit(
        (api, token) => api.applyAsHead(token, club.id),
        'Request submitted for review.',
      );
    }
  }

  Future<void> _review(JsonObject request) async {
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request['club_name'] as String),
        content: Text('Applicant: ${request['applicant_name']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reject'),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'approve'),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (!mounted || decision == null) return;
    final reject = decision == 'reject';
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(reject ? 'Confirm rejection' : 'Confirm approval'),
          content: reject
              ? TextField(
                  maxLength: 1000,
                  onChanged: (value) => update(() => reason = value.trim()),
                  decoration: const InputDecoration(
                    labelText: 'Reason the applicant will see',
                  ),
                )
              : const Text(
                  'This assigns the applicant as the Club Head and closes applications.',
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: reject && reason.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(reject ? 'Reject request' : 'Approve request'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    await _submit(
      (api, token) => api.decideHeadRequest(
        token,
        request['id'] as String,
        rejectionReason: reject ? reason : null,
      ),
      reject ? 'Request rejected.' : 'Club Head assigned.',
    );
  }

  String _status(String? value) => switch (value) {
    'open' => 'Open',
    'locked' => 'Locked',
    'assigned' => 'Assigned',
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'Unavailable',
  };

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final title = club == null ? 'Club Head requests' : club.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(club == null ? 'Club Head requests' : 'Apply as Club Head'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  CampusHeader(
                    title,
                    widget.review
                        ? 'Review applicants for vacant Club Head roles.'
                        : club == null
                        ? 'Track your applications and review decisions.'
                        : 'Check availability and submit a request to lead this club.',
                    icon: Icons.groups_outlined,
                  ),
                  const SizedBox(height: 16),
                  if (_loading || _submitting) const LinearProgressIndicator(),
                  if (_error case final error?)
                    CampusFeedback(
                      error,
                      icon: Icons.error_outline,
                      retry: _load,
                    ),
                  if (!_loading && _error == null) ...[
                    if (club != null) ...[
                      Card(
                        child: ListTile(
                          title: const Text('Club Head applications'),
                          trailing: CampusStatus(_status(_availability)),
                          subtitle: Text(switch (_availability) {
                            'open' => 'You can submit an application.',
                            'locked' => 'An application is under review.',
                            _ => 'This club already has a Club Head.',
                          }),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_availability == 'open')
                        FilledButton(
                          onPressed: _submitting ? null : () => _apply(club),
                          child: const Text('Apply as Club Head'),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (_requests.isEmpty)
                      CampusFeedback(
                        widget.review
                            ? 'No pending requests.'
                            : 'No Club Head requests yet.',
                        icon: Icons.inbox_outlined,
                      ),
                    for (final request in _requests)
                      Card(
                        child: ListTile(
                          title: Text(request['club_name'] as String),
                          subtitle: Text(
                            (request['reason'] ??
                                    request['applicant_name'] ??
                                    'Club Head application')
                                as String,
                          ),
                          trailing: CampusStatus(
                            _status(request['status'] as String),
                          ),
                          onTap: widget.review && !_submitting
                              ? () => _review(request)
                              : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
