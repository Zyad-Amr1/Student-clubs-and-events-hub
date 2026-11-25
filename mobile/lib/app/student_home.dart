import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/auth/presentation/profile_screen.dart';
import 'package:campusconnect/features/clubs/presentation/club_details_screen.dart';
import 'package:campusconnect/features/clubs/presentation/club_lifecycle_screen.dart';
import 'package:campusconnect/features/clubs/presentation/clubs_screen.dart';
import 'package:campusconnect/features/events/presentation/my_events_screen.dart';
import 'package:campusconnect/features/events/presentation/student_event_details_screen.dart';
import 'package:material_ui/material_ui.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({this.initialTab = 1, super.key});

  final int initialTab;

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late int _tab = widget.initialTab;

  void _setTab(int index) {
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CampusColors.canvas,
    body: switch (_tab) {
      0 => _StudentDashboardView(
        onOpenClubs: () => _setTab(1),
        onOpenCalendar: () => _setTab(2),
        onOpenProfile: () => _setTab(3),
      ),
      1 => const ClubsScreen(),
      2 => const MyEventsScreen(),
      _ => const ProfileScreen(),
    },
    bottomNavigationBar: CampusBottomNavigation(index: _tab, onSelect: _setTab),
  );
}

class _StudentDashboardView extends StatefulWidget {
  const _StudentDashboardView({
    required this.onOpenClubs,
    required this.onOpenCalendar,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenClubs;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenProfile;

  @override
  State<_StudentDashboardView> createState() => _StudentDashboardViewState();
}

class _StudentDashboardViewState extends State<_StudentDashboardView> {
  bool _loading = true;
  String? _error;
  String? _reservationError;
  List<CampusClub> _clubs = [];
  List<EventReservation> _reservations = [];
  CampusEvent? _featuredEvent;

  List<EventReservation> get _upcomingReservations => _reservations
      .where(
        (reservation) =>
            reservation.status != ReservationStatus.cancelled &&
            reservation.event.startsAt.isAfter(DateTime.now()),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final session = StudentSessionScope.of(context);
    if (!session.signedIn) return;
    setState(() {
      _loading = true;
      _error = null;
      _reservationError = null;
    });

    try {
      final token = await session.authenticated((t) async => t);

      // Load clubs list and total
      final clubPage = await session.api.clubs(token, page: 1);
      _clubs = clubPage.clubs;

      // Load active reservations
      try {
        final res = await session.api.myReservations(token);
        _reservations = res
          ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
      } catch (_) {
        _reservations = [];
        _reservationError = 'Could not load your reservations. Please retry.';
      }

      CampusEvent? featured;

      final now = DateTime.now();
      for (final r in _reservations) {
        if (r.status != ReservationStatus.cancelled &&
            r.event.startsAt.isAfter(now)) {
          featured ??= r.event;
        }
      }

      // If no upcoming booked event, check the first club's approved events
      if (featured == null && _clubs.isNotEmpty) {
        try {
          final details = await session.api.clubDetails(token, _clubs.first.id);
          for (final event in details.events) {
            if (event.startsAt.isAfter(now)) {
              featured = event;
              break;
            }
          }
        } catch (_) {
          // Gracefully continue without featured event
        }
      }

      if (!mounted) return;
      setState(() {
        _featuredEvent = featured;
        _loading = false;
      });
    } on ApiFailure catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load campus data. Please retry.';
        _loading = false;
      });
    }
  }

  void _openEvent(CampusEvent event) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => StudentEventDetailsScreen(event: event),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
  }

  void _openClub(CampusClub club) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ClubDetailsScreen(club: club),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
  }

  String _formatMonthDay(DateTime dt) {
    final local = dt.toLocal();
    final l10n = MaterialLocalizations.of(context);
    return '${l10n.formatMonthYear(local).split(' ').first.substring(0, 3)} ${local.day}';
  }

  String _formatWeekday(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.toLocal().weekday - 1];
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final l10n = MaterialLocalizations.of(context);
    return l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  }

  @override
  Widget build(BuildContext context) {
    final session = StudentSessionScope.of(context);
    final user = session.profile;
    final firstName = user?.fullName.split(' ').first ?? 'Student';

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: CampusColors.purple,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(context, firstName),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),

                  // Shortcuts map only to existing app destinations.
                  Row(
                    children: [
                      CampusQuickAction(
                        icon: Icons.groups_rounded,
                        label: 'Explore Clubs',
                        onTap: widget.onOpenClubs,
                      ),
                      CampusQuickAction(
                        icon: Icons.event_outlined,
                        label: 'Events',
                        onTap: widget.onOpenCalendar,
                      ),
                      CampusQuickAction(
                        icon: Icons.bookmark_border_rounded,
                        label: 'My Bookings',
                        onTap: widget.onOpenCalendar,
                      ),
                      CampusQuickAction(
                        icon: Icons.calendar_month_outlined,
                        label: 'Calendar',
                        onTap: widget.onOpenCalendar,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // The summary and reservation states come from the backend.
                  CampusSectionHeader(
                    title: 'Upcoming Events',
                    icon: Icons.calendar_month_outlined,
                    actionLabel: 'View Calendar',
                    onAction: widget.onOpenCalendar,
                  ),
                  const SizedBox(height: 8),
                  if (_featuredEvent != null) ...[
                    _buildFeaturedCard(context, _featuredEvent!),
                    const SizedBox(height: 12),
                  ],
                  _buildUpcomingEventsList(context),

                  const SizedBox(height: 26),

                  // Explore Clubs Section
                  CampusSectionHeader(
                    title: 'Explore Clubs',
                    icon: Icons.groups_outlined,
                    actionLabel: 'View all',
                    onAction: widget.onOpenClubs,
                  ),
                  const SizedBox(height: 8),
                  _buildExploreClubsRow(context),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String firstName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 8,
        18,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F0730),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: CampusBrandLockup(logoSize: 34, fontSize: 18),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ClubLifecycleScreen(studentNotices: true),
                  ),
                ),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: CampusColors.purple,
                  size: 24,
                ),
              ),
              IconButton(
                key: const ValueKey('header-open-profile'),
                tooltip: 'Student profile',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.profile),
                icon: const Icon(
                  Icons.account_circle_outlined,
                  color: CampusColors.purple,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $firstName 👋',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'What’s happening on campus?',
                      style: TextStyle(
                        color: CampusColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 100,
                  height: 78,
                  child: Image.asset(
                    'assets/images/campus-hero.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, CampusEvent event) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEvent(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Image(
              image: AssetImage('assets/images/campus-hero.png'),
              height: 112,
              fit: BoxFit.cover,
              alignment: Alignment(0, 0.35),
              excludeFromSemantics: true,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: CampusColors.lavender,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      _formatMonthDay(event.startsAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: CampusColors.purpleDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('${event.venue} · ${_formatTime(event.startsAt)}'),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: CampusColors.purple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsList(BuildContext context) {
    if (_reservationError case final error?) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: CampusColors.redFg),
              const SizedBox(width: 12),
              Expanded(child: Text(error)),
              TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final upcoming = _upcomingReservations;
    if (upcoming.isEmpty) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CampusColors.lavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: CampusColors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No upcoming reservations',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: CampusColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore clubs and reserve your place.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'My Events Calendar',
                child: TextButton(
                  onPressed: widget.onOpenCalendar,
                  child: const Text('Calendar'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayEvents = upcoming.take(3).toList();
    return Column(
      children: [
        for (final reservation in displayEvents)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _openEvent(reservation.event),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: CampusColors.lavender,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatWeekday(reservation.event.startsAt),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: CampusColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatMonthDay(reservation.event.startsAt),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: CampusColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 48, color: CampusColors.line),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reservation.event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CampusColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 12,
                                color: CampusColors.inkMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatTime(reservation.event.startsAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CampusColors.inkMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: CampusColors.inkMuted,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  reservation.event.venue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: CampusColors.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CampusStatus(
                      reservation.status == ReservationStatus.confirmed
                          ? 'Confirmed'
                          : reservation.status == ReservationStatus.waitlisted
                          ? 'Waiting List'
                          : 'Cancelled',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExploreClubsRow(BuildContext context) {
    if (_loading && _clubs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: CampusColors.purple),
        ),
      );
    }

    if (_error != null && _clubs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('retry-clubs'),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_clubs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No approved active clubs are available yet.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _clubs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final club = _clubs[index];
          return SizedBox(
            width: 104,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: ValueKey('club-${club.id}'),
                onTap: () => _openClub(club),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CampusColors.line),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C391B50),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CampusColors.lavender,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon(club.category),
                          color: CampusColors.purple,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        club.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CampusColors.ink,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
