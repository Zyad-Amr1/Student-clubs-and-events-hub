import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

/// Student Affairs only; server validates JWT and role for every operation.
class ReviewEventsScreen extends StatefulWidget {
  const ReviewEventsScreen({super.key});

  @override
  State<ReviewEventsScreen> createState() => _ReviewEventsScreenState();
}

class _ReviewEventsScreenState extends State<ReviewEventsScreen> {
  final List<ManagedEvent> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _actingId;
  String? _error;
  String? _lastAction;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
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
        (token) => session.api.pendingEventReviews(token, page: _page),
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(result.events);
        _total = result.total;
        _page++;
      });
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load pending events.');
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  Future<void> _review(ManagedEvent event, String decision) async {
    setState(() {
      _actingId = event.id;
      _error = null;
      _lastAction = null;
    });
    try {
      final session = StudentSessionScope.of(context);
      final result = await session.authenticated(
        (token) => session.api.reviewEvent(token, event.id, decision: decision),
      );
      if (!mounted) return;
      setState(() {
        _lastAction = result.approvalStatus == 'approved'
            ? '${result.title}: approved and published'
            : '${result.title}: rejected and unpublished';
      });
      await _load(reset: true);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not review event.');
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pending event reviews'),
      actions: [
        IconButton(
          key: const ValueKey('refresh-pending'),
          tooltip: 'Refresh',
          onPressed: _actingId == null ? () => _load(reset: true) : null,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Awaiting review: $_total',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (_lastAction != null)
                  Text(_lastAction!, key: const ValueKey('review-result')),
                if (_error != null) ...[
                  Text(
                    _error!,
                    key: const ValueKey('review-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('Retry'),
                  ),
                ],
                if (_events.isEmpty) const Text('No pending events to review.'),
                for (final event in _events)
                  Card(
                    key: ValueKey('pending-event-${event.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(event.description),
                          Text('Venue: ${event.venue}'),
                          Text('Start: ${event.startsAt.toLocal()}'),
                          Text('Capacity: ${event.seatCapacity}'),
                          const Text('Status: pending · Not published'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton(
                                key: ValueKey('approve-${event.id}'),
                                onPressed: _actingId == null
                                    ? () => _review(event, 'approve')
                                    : null,
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                key: ValueKey('reject-${event.id}'),
                                onPressed: _actingId == null
                                    ? () => _review(event, 'reject')
                                    : null,
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_events.length < _total)
                  TextButton(
                    key: const ValueKey('load-more-pending'),
                    onPressed: _loadingMore || _actingId != null
                        ? null
                        : () => _load(),
                    child: Text(_loadingMore ? 'Loading...' : 'Load more'),
                  ),
              ],
            ),
    ),
  );
}
