import 'dart:async';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/clubs/presentation/club_details_screen.dart';
import 'package:campusconnect/features/events/presentation/my_events_screen.dart';
import 'package:material_ui/material_ui.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final List<CampusClub> _clubs = [];
  final TextEditingController _searchController = TextEditingController();
  final _categoryController = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _searchController.text.trim().isNotEmpty ||
      _categoryController.text.trim().isNotEmpty;

  void _criteriaChanged() {
    _debounce?.cancel();
    _generation++;
    setState(() => _loading = true);
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(reset: true),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    _categoryController.clear();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted) return;
    if (reset) {
      _debounce?.cancel();
      _generation++;
      setState(() {
        _clubs.clear();
        _total = 0;
        _page = 1;
        _loading = true;
        _loadingMore = false;
        _error = null;
      });
    } else {
      if (_loadingMore || _clubs.length >= _total) return;
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }
    final generation = _generation;
    final page = _page;
    final search = _searchController.text;
    final category = _categoryController.text;
    try {
      final session = StudentSessionScope.of(context);
      final result = await session.authenticated(
        (token) => session.api.clubs(
          token,
          page: page,
          search: search,
          category: category,
        ),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _clubs.addAll(result.clubs);
        _total = result.total;
        _page++;
      });
    } on ApiFailure catch (error) {
      if (!mounted || generation != _generation) return;
      if (error.statusCode == 401) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.authentication, (route) => false);
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Could not load clubs. Please retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = StudentSessionScope.of(context);
    if (!session.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clubs')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.authentication,
              (route) => false,
            ),
            child: const Text('Sign in to browse clubs'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover clubs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('club-search'),
                  controller: _searchController,
                  onChanged: (_) => _criteriaChanged(),
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Search clubs by name',
                    prefixIcon: Icon(Icons.search),
                    counterText: '',
                  ),
                ),
                TextField(
                  key: const ValueKey('club-category-filter'),
                  controller: _categoryController,
                  maxLength: 80,
                  onChanged: (_) => _criteriaChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Filter by category (exact name)',
                    prefixIcon: Icon(Icons.filter_list),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Events Calendar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyEventsScreen()),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            key: const ValueKey('open-profile'),
            tooltip: 'Student profile',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _clubs.isEmpty
            ? _MessageState(message: _error!, onRetry: () => _load(reset: true))
            : _clubs.isEmpty
            ? _MessageState(
                message: _filtered
                    ? 'No clubs match your search and category.'
                    : 'No approved active clubs are available yet.',
                onRetry: _filtered ? _clearFilters : () => _load(reset: true),
                actionLabel: _filtered ? 'Clear filters' : 'Refresh',
              )
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView.builder(
                  key: const ValueKey('club-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _clubs.length +
                      (_clubs.length < _total || _error != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _clubs.length) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: _error != null
                            ? Column(
                                children: [
                                  Text(_error!),
                                  TextButton(
                                    onPressed: _loadingMore
                                        ? null
                                        : () => _load(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              )
                            : Center(
                                child: TextButton(
                                  key: const ValueKey('load-more-clubs'),
                                  onPressed: _loadingMore
                                      ? null
                                      : () => _load(),
                                  child: Text(
                                    _loadingMore
                                        ? 'Loading...'
                                        : 'Load more clubs',
                                  ),
                                ),
                              ),
                      );
                    }
                    final club = _clubs[index];
                    return Card(
                      child: ListTile(
                        key: ValueKey('club-${club.id}'),
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(club.name),
                        subtitle: Text(
                          '${club.category} · ${club.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ClubDetailsScreen(club: club),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Refresh',
  });

  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore_outlined, size: 52),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey('retry-clubs'),
            onPressed: onRetry,
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
