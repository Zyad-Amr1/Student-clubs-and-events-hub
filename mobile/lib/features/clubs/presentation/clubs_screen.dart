import 'dart:async';

import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:campusconnect/features/clubs/models/club.dart';
import 'package:campusconnect/features/clubs/presentation/club_details_screen.dart';
import 'package:material_ui/material_ui.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _searchController = TextEditingController();
  final _categories = <String>{};
  List<ClubSummary> _clubs = const [];
  Timer? _searchDebounce;
  bool _loading = true;
  bool _loadingMore = false;
  String _category = '';
  String? _error;
  int _total = 0;
  int _page = 1;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs({bool append = false}) async {
    final requestId = ++_requestId;
    final accessToken = widget.controller.sessionToken;
    if (accessToken == null) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Sign in to browse clubs.';
      });
      return;
    }
    setState(() {
      _loading = !append;
      _loadingMore = append;
      _error = null;
    });
    try {
      final page = await widget.controller.clubsRepository.browse(
        accessToken: accessToken,
        page: append ? _page + 1 : 1,
        search: _searchController.text,
        category: _category,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        final results = append ? [..._clubs, ...page.clubs] : page.clubs;
        final seenIds = <String>{};
        _clubs = results
            .where((club) => seenIds.add(club.id))
            .toList(growable: false);
        _page = page.page;
        _total = page.total;
        _categories.addAll(page.clubs.map((club) => club.category));
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error.message;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = 'Could not load clubs. Please try again.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadClubs);
    setState(() {});
  }

  List<ClubSummary> get _visibleClubs {
    final query = _searchController.text.trim().toLowerCase();
    return _clubs
        .where((club) {
          final matchesName =
              query.isEmpty || club.name.toLowerCase().contains(query);
          final matchesCategory =
              _category.isEmpty ||
              club.category.toLowerCase() == _category.toLowerCase();
          return matchesName && matchesCategory;
        })
        .toList(growable: false);
  }

  bool get _hasMore => !_loading && _clubs.length < _total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleClubs = _visibleClubs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Club discovery'),
        actions: [
          IconButton(
            key: const ValueKey<String>('open-profile'),
            tooltip: 'Account profile',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey<String>('club-search'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: 'Search club names',
                      prefixIcon: const Icon(Icons.search),
                      counterText: '',
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey<String>('club-category-filter'),
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All categories'),
                      ),
                      for (final category in (_categories.toList()..sort()))
                        DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _category = value ?? '');
                      _loadClubs();
                    },
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null && _clubs.isNotEmpty)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(onPressed: _loadClubs, child: const Text('Retry')),
                ],
              ),
            Expanded(
              child: _error != null && _clubs.isEmpty
                  ? _LoadError(message: _error!, onRetry: _loadClubs)
                  : _loading && _clubs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : visibleClubs.isEmpty
                  ? _EmptyClubs(
                      hasFilter:
                          _searchController.text.trim().isNotEmpty ||
                          _category.isNotEmpty,
                      hasMore: _hasMore,
                      loading: _loadingMore,
                      onLoadMore: () => _loadClubs(append: true),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadClubs,
                      child: ListView.separated(
                        key: const ValueKey<String>('club-list'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: visibleClubs.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == visibleClubs.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: OutlinedButton(
                                  key: const ValueKey<String>(
                                    'load-more-clubs',
                                  ),
                                  onPressed: _loadingMore
                                      ? null
                                      : () => _loadClubs(append: true),
                                  child: _loadingMore
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Load more clubs'),
                                ),
                              ),
                            );
                          }
                          final club = visibleClubs[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: ListTile(
                              key: ValueKey<String>('club-${club.id}'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.groups_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                club.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(club.category),
                                    if (club.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        club.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ClubDetailsScreen(
                                    controller: widget.controller,
                                    club: club,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClubs extends StatelessWidget {
  const _EmptyClubs({
    required this.hasFilter,
    required this.hasMore,
    required this.loading,
    required this.onLoadMore,
  });

  final bool hasFilter;
  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 42),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? 'No clubs match these filters.'
                  : 'No approved clubs are available yet.',
              textAlign: TextAlign.center,
            ),
            if (hasMore) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: loading ? null : onLoadMore,
                child: Text(loading ? 'Loading...' : 'Load more clubs'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey<String>('retry-club-load'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
