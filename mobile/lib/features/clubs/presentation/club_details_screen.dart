import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
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
  String? _error;

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
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('Retry details'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  key: const ValueKey('club-details'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      club.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      club.category,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(club.description),
                    const SizedBox(height: 26),
                    Text(
                      'Upcoming approved events',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_events.isEmpty)
                      const Text('No upcoming published events for this club.'),
                    for (final event in _events)
                      Card(
                        key: ValueKey('event-${event.id}'),
                        child: ListTile(
                          title: Text(event.title),
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
