import 'dart:async';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/clubs/presentation/club_details_screen.dart';
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
      backgroundColor: CampusColors.canvas,
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 105,
              pinned: true,
              backgroundColor: CampusColors.purple,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: CampusColors.gradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explore Clubs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'Discover and join university clubs',
                                style: TextStyle(
                                  color: Color(0xFFECD6FC),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: Column(
            children: [
              // Search + Filter bar
              Container(
                color: CampusColors.canvas,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('club-search'),
                            controller: _searchController,
                            onChanged: (_) => _criteriaChanged(),
                            maxLength: 120,
                            decoration: InputDecoration(
                              hintText:
                                  'Search clubs (e.g., Robotics, AI, Media)...',
                              prefixIcon: const Icon(Icons.search),
                              counterText: '',
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _criteriaChanged();
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Filter icon
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => _showFilterSheet(context),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: CampusColors.line),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: _categoryController.text.isNotEmpty
                                    ? CampusColors.purple
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Keep exact category entry available for server-side filtering.
                    const SizedBox(height: 10),
                    _buildCategoryChips(),
                    TextField(
                      key: const ValueKey('club-category-filter'),
                      controller: _categoryController,
                      maxLength: 80,
                      onChanged: (_) => _criteriaChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.filter_list),
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // Club list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _clubs.isEmpty
                    ? _MessageState(
                        message: _error!,
                        onRetry: () => _load(reset: true),
                      )
                    : _clubs.isEmpty
                    ? _MessageState(
                        message: _filtered
                            ? 'No clubs match your search and category.'
                            : 'No approved active clubs are available yet.',
                        onRetry: _filtered
                            ? _clearFilters
                            : () => _load(reset: true),
                        actionLabel: _filtered ? 'Clear filters' : 'Refresh',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: GridView.builder(
                          key: const ValueKey('club-list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 260,
                              ),
                          itemCount:
                              _clubs.length +
                              (_clubs.length < _total || _error != null
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (index == _clubs.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _error != null
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
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
                                      : TextButton(
                                          key: const ValueKey(
                                            'load-more-clubs',
                                          ),
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
                            return _ClubCard(
                              key: ValueKey('club-${club.id}'),
                              club: club,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      ClubDetailsScreen(club: club),
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
      ),
    );
  }

  // Category quick-filter chips
  Widget _buildCategoryChips() {
    final categories = [
      ('All Clubs', '', Icons.grid_view_rounded),
      ('Tech', 'Tech', Icons.code_rounded),
      ('Engineering', 'Engineering', Icons.settings_suggest_rounded),
      ('Arts', 'Arts', Icons.palette_outlined),
      ('Sports', 'Sports', Icons.sports_basketball_outlined),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, value, icon) = categories[i];
          final selected = _categoryController.text == value;
          return GestureDetector(
            onTap: () {
              _categoryController.text = value;
              _criteriaChanged();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? CampusColors.purple : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? CampusColors.purple : CampusColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : CampusColors.inkMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : CampusColors.inkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter by Category',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: CampusColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('club-category-filter-sheet'),
              controller: _categoryController,
              maxLength: 80,
              onChanged: (_) => _criteriaChanged(),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category (exact name)',
                prefixIcon: Icon(Icons.filter_list),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Apply filter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club, required this.onTap, super.key});

  final CampusClub club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CampusColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C391B50),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club icon avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CampusColors.lavender,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    categoryIcon(club.category),
                    color: CampusColors.purple,
                    size: 24,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              club.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: CampusColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              club.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: CampusColors.inkMuted,
                height: 1.3,
              ),
            ),
            const Spacer(),
            // Category chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CampusColors.lavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    categoryIcon(club.category),
                    size: 10,
                    color: CampusColors.purple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    club.category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: CampusColors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Open the club to see its real membership options.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CampusColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size.fromHeight(32),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward, size: 14),
                    SizedBox(width: 3),
                    Text('View club'),
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
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CampusColors.lavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 40,
              color: CampusColors.purple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CampusColors.inkMuted, fontSize: 15),
          ),
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
