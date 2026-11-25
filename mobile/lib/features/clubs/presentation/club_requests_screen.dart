import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/clubs/presentation/club_management_form.dart';
import 'package:campusconnect/shared/widgets/pick_image.dart';
import 'package:material_ui/material_ui.dart';

class ClubRequestsScreen extends StatefulWidget {
  const ClubRequestsScreen({this.review = false, super.key});
  final bool review;

  @override
  State<ClubRequestsScreen> createState() => _ClubRequestsScreenState();
}

class _ClubRequestsScreenState extends State<ClubRequestsScreen> {
  final _requests = <ClubCreationRequest>[];
  var _page = 1;
  var _hasMore = false;
  var _busy = false;
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
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = StudentSessionScope.of(context);
    try {
      final result = await session.authenticated(
        (token) => session.api.clubRequests(
          token,
          review: widget.review,
          page: reset ? 1 : _page,
        ),
      );
      if (!mounted) return;
      if (reset) {
        _page = 1;
        _requests.clear();
      }
      _requests.addAll(result.requests);
      _hasMore = result.hasMore;
      _page++;
    } on ApiFailure catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (_) => screen));
    if (mounted) await _load(reset: true);
  }

  Future<void> _withdraw(ClubCreationRequest request) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw this request?'),
        content: const Text('The request will remain in your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || _busy) return;
    final session = StudentSessionScope.of(context);
    setState(() => _busy = true);
    try {
      await session.authenticated(
        (token) => session.api.withdrawClubRequest(token, request.id),
      );
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load(reset: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = StudentSessionScope.of(context).signedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.review ? 'Review Club Requests' : 'My Club Requests',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
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
              const Text('Sign in again to view requests.')
            else ...[
              if (!widget.review)
                FilledButton(
                  onPressed:
                      _busy || _requests.any((request) => request.pending)
                      ? null
                      : () => _open(const ClubManagementForm()),
                  child: const Text('Request a New Club'),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: _busy ? null : () => _load(reset: true),
                  child: const Text('Retry'),
                ),
              ] else if (!_busy && _requests.isEmpty)
                Text(
                  widget.review
                      ? 'No pending club requests.'
                      : 'You have no club requests yet.',
                ),
              for (final request in _requests)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${request.statusLabel} · ${request.category}'),
                        Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(request.createdAt.toLocal()),
                        ),
                        Text(request.description),
                        if (request.rejectionReason != null)
                          Text('Reason · ${request.rejectionReason}'),
                        if (request.pending)
                          Wrap(
                            children: [
                              if (widget.review)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            _open(_ReviewClubRequest(request)),
                                  child: const Text('Review request'),
                                )
                              else ...[
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _open(
                                          ClubManagementForm(request: request),
                                        ),
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _withdraw(request),
                                  child: const Text('Withdraw'),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              if (_hasMore)
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Load more requests'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewClubRequest extends StatefulWidget {
  const _ReviewClubRequest(this.request);
  final ClubCreationRequest request;

  @override
  State<_ReviewClubRequest> createState() => _ReviewClubRequestState();
}

class _ReviewClubRequestState extends State<_ReviewClubRequest> {
  final _reason = TextEditingController();
  Future<List<CampusClub>>? _similar;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _similar ??= _loadSimilar();
  }

  Future<List<CampusClub>> _loadSimilar() {
    final session = StudentSessionScope.of(context);
    return session.authenticated(
      (token) => session.api.similarClubs(token, widget.request.id),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    if (decision == 'reject' && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter a rejection reason the student can see.');
      return;
    }
    final session = StudentSessionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.authenticated(
        (token) => session.api.decideClubRequest(
          token,
          widget.request.id,
          decision,
          reason: decision == 'reject' ? _reason.text.trim() : null,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final signedIn = StudentSessionScope.of(context).signedIn;
    return Scaffold(
      appBar: AppBar(title: Text(request.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: UploadedImage(request.logoUrl)),
            Text(request.category),
            Text(request.description),
            const SizedBox(height: 16),
            Text(
              'Active clubs in this category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FutureBuilder<List<CampusClub>>(
              future: _similar,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: signedIn
                        ? () => setState(() => _similar = _loadSimilar())
                        : null,
                    child: const Text('Could not load related clubs. Retry'),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Text('No active clubs in this category.');
                }
                return Column(
                  children: [
                    for (final club in snapshot.data!)
                      ListTile(
                        title: Text(club.name),
                        subtitle: Text(club.description),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              enabled: !_busy && signedIn,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason shown to the student if rejected',
              ),
            ),
            if (_error != null) Text(_error!),
            if (_busy) const LinearProgressIndicator(),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: _busy || !signedIn
                      ? null
                      : () => _decide('approve'),
                  child: const Text('Approve and publish'),
                ),
                OutlinedButton(
                  onPressed: _busy || !signedIn
                      ? null
                      : () => _decide('reject'),
                  child: const Text('Reject request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
