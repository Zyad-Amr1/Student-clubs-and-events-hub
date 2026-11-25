import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

class ClubLifecycleScreen extends StatefulWidget {
  const ClubLifecycleScreen({this.studentNotices = false, super.key});

  final bool studentNotices;

  @override
  State<ClubLifecycleScreen> createState() => _ClubLifecycleScreenState();
}

class _ClubLifecycleScreenState extends State<ClubLifecycleScreen> {
  final _archiveReason = TextEditingController();
  final _reactivationReason = TextEditingController();
  List<JsonObject> _clubs = [];
  List<JsonObject> _notices = [];
  bool _loading = true;
  String? _error;

  @override
  void dispose() {
    _archiveReason.dispose();
    _reactivationReason.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = StudentSessionScope.of(context);
    try {
      if (widget.studentNotices) {
        final data = await session.authenticated(
          session.api.clubLifecycleNotices,
        );
        _notices = (data['notices'] as List).cast<JsonObject>();
      } else {
        final data = await session.authenticated(session.api.lifecycleClubs);
        _clubs = (data['clubs'] as List).cast<JsonObject>();
      }
    } on ApiFailure catch (error) {
      _error = error.message;
    } on Object {
      _error = 'Could not load club lifecycle information.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _archive(JsonObject club) async {
    final session = StudentSessionScope.of(context);
    try {
      final preview = await session.authenticated(
        (token) => session.api.archivePreview(token, club['id'] as String),
      );
      if (!mounted) return;
      _archiveReason.clear();
      final events = (preview['events'] as List).length;
      final days = (preview['interview_days'] as List).length;
      final eventRows = (preview['events'] as List).cast<JsonObject>();
      final dayRows = (preview['interview_days'] as List).cast<JsonObject>();
      final studentNames = (preview['affected_students'] as List)
          .cast<String>();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Archive ${club['name']}?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$events future events and $days interview days will be cancelled.',
                ),
                if (eventRows.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Events'),
                  for (final event in eventRows)
                    Text('• ${event['title']} · ${event['starts_at']}'),
                ],
                if (dayRows.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Interview days'),
                  for (final day in dayRows) Text('• ${day['day']}'),
                ],
                if (studentNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Affected students: ${studentNames.join(', ')}'),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _archiveReason,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Reason students will see',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm archive'),
            ),
          ],
        ),
      );
      final reason = _archiveReason.text.trim();
      _archiveReason.clear();
      if (accepted != true) return;
      if (reason.isEmpty) throw const ApiFailure('Enter an archival reason.');
      await session.authenticated(
        (token) => session.api.archiveClub(
          token,
          club['id'] as String,
          reason,
          preview['preview_token'] as String,
        ),
      );
      await _load();
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _reactivate(JsonObject club) async {
    _reactivationReason.clear();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reactivate ${club['name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Previously cancelled events and interviews will remain cancelled.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reactivationReason,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Optional reactivation reason',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    final session = StudentSessionScope.of(context);
    try {
      await session.authenticated(
        (token) => session.api.reactivateClub(
          token,
          club['id'] as String,
          reason: _reactivationReason.text.trim().isEmpty
              ? null
              : _reactivationReason.text.trim(),
        ),
      );
      _reactivationReason.clear();
      await _load();
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _history(JsonObject club) async {
    final session = StudentSessionScope.of(context);
    try {
      final result = await session.authenticated(
        (token) =>
            session.api.clubLifecycleHistory(token, club['id'] as String),
      );
      if (!mounted) return;
      final rows = (result['history'] as List).cast<JsonObject>();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${club['name']} history'),
          content: SizedBox(
            width: 360,
            child: rows.isEmpty
                ? const Text('No lifecycle history yet.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(
                            row['action'] == 'archived'
                                ? 'Archived'
                                : 'Reactivated',
                          ),
                          subtitle: Text(
                            '${row['reason'] ?? 'No reason recorded'} · ${row['created_at']}',
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.studentNotices ? 'Club notifications' : 'Club lifecycle',
      ),
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  CampusFeedback(
                    _error!,
                    icon: Icons.error_outline,
                    retry: _load,
                  ),
                ],
              )
            : widget.studentNotices
            ? _notices.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: const [
                        CampusFeedback(
                          'No club notifications yet.',
                          icon: Icons.notifications_none_rounded,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final notice in _notices)
                          Card(
                            child: ListTile(
                              leading: const CampusIconTile(
                                Icons.notifications_outlined,
                              ),
                              title: Text(notice['club_name'] as String),
                              subtitle: Text(notice['message'] as String),
                            ),
                          ),
                      ],
                    )
            : _clubs.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  CampusFeedback(
                    'No approved clubs.',
                    icon: Icons.groups_outlined,
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final club in _clubs)
                    Card(
                      child: ListTile(
                        title: Text(club['name'] as String),
                        subtitle: Text(
                          club['is_active'] == true
                              ? 'Active'
                              : 'Archived: ${club['archive_reason'] ?? 'No reason recorded'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Lifecycle history',
                              onPressed: () => _history(club),
                              icon: const Icon(Icons.history),
                            ),
                            if (club['is_active'] == true)
                              TextButton(
                                onPressed: () => _archive(club),
                                child: const Text('Archive'),
                              )
                            else
                              TextButton(
                                onPressed: () => _reactivate(club),
                                child: const Text('Reactivate'),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );
}
