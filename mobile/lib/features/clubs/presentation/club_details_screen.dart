import 'package:campusconnect/features/clubs/presentation/club_head_screen.dart';
import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/shared/widgets/pick_image.dart';
import 'package:campusconnect/features/events/presentation/student_event_details_screen.dart';
import 'package:material_ui/material_ui.dart';

class ClubDetailsScreen extends StatefulWidget {
  const ClubDetailsScreen({required this.club, super.key});

  final CampusClub club;

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  ClubDetails? _details;
  final List<CampusEvent> _events = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _applying = false;
  bool _hasApplication = false;
  String? _error;

  Future<void> _apply() async {
    if (_applying) return;
    final session = StudentSessionScope.of(context);
    setState(() => _applying = true);
    String message;
    try {
      await session.authenticated(
        (token) => session.api.applyToClub(token, widget.club.id),
      );
      _hasApplication = true;
      message = 'Application submitted. Track it in My Applications.';
    } on ApiFailure catch (error) {
      _hasApplication = error.statusCode == 409;
      message = error.message;
    } finally {
      if (mounted) setState(() => _applying = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _details = null;
        _events.clear();
        _page = 1;
        _total = 0;
        _loading = true;
        _error = null;
      });
    } else {
      if (_loadingMore || _events.length >= _total) return;
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }
    try {
      final session = StudentSessionScope.of(context);
      final result = await session.authenticated(
        (token) => session.api.clubDetails(token, widget.club.id, page: _page),
      );
      if (!mounted) return;
      setState(() {
        _details = result;
        _events.addAll(result.events);
        _total = result.total;
        _page++;
      });
    } on ApiFailure catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.authentication, (route) => false);
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load club details.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = _details?.club ?? widget.club;
    return Scaffold(
      appBar: AppBar(title: Text(club.name)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _details == null
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  CampusFeedback(
                    _error!,
                    icon: Icons.error_outline,
                    retry: () => _load(reset: true),
                    retryLabel: 'Retry details',
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  key: const ValueKey('club-details'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    CampusHeader(
                      club.name,
                      club.category,
                      icon: Icons.groups_outlined,
                      trailing:
                          (club.logoUrl?.startsWith(
                                'data:image/jpeg;base64,',
                              ) ??
                              false)
                          ? UploadedImage(club.logoUrl, size: 48)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          club.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _applying || _hasApplication ? null : _apply,
                      child: Text(
                        _hasApplication
                            ? 'Application on file'
                            : 'Apply to join',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ClubHeadScreen(club: club),
                        ),
                      ),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Club Head vacancy'),
                    ),
                    const SizedBox(height: 12),
                    const CampusSectionHeader(
                      title: 'Upcoming approved events',
                    ),
                    if (_events.isEmpty)
                      const CampusFeedback(
                        'No upcoming published events for this club.',
                        icon: Icons.event_busy_outlined,
                      ),
                    for (final event in _events)
                      Card(
                        key: ValueKey('event-${event.id}'),
                        child: ListTile(
                          title: Text(event.title),
                          leading: const CampusIconTile(Icons.event_outlined),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  StudentEventDetailsScreen(event: event),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.description),
                              const SizedBox(height: 8),
                              Text('Venue: ${event.venue}'),
                              Text(_formatEventTime(context, event.startsAt)),
                              Text('Capacity: ${event.seatCapacity}'),
                            ],
                          ),
                        ),
                      ),
                    if (_error != null && _details != null) Text(_error!),
                    if (_events.length < _total)
                      TextButton(
                        key: const ValueKey('load-more-events'),
                        onPressed: _loadingMore ? null : () => _load(),
                        child: Text(
                          _loadingMore ? 'Loading...' : 'Load more events',
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatEventTime(BuildContext context, DateTime time) {
    final local = time.toLocal();
    final l10n = MaterialLocalizations.of(context);
    return '${l10n.formatFullDate(local)} · ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}
