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
import 'package:campusconnect/shared/widgets/pick_image.dart';
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
  List<CampusClub> _clubs = [];
  int _totalClubs = 0;
  List<EventReservation> _reservations = [];
  CampusEvent? _featuredEvent;
  int _upcomingEventsCount = 0;

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
    });

    try {
      final token = await session.authenticated((t) async => t);

      // Load clubs list and total
      final clubPage = await session.api.clubs(token, page: 1);
      _clubs = clubPage.clubs;
      _totalClubs = clubPage.total;

      // Load active reservations
      try {
        final res = await session.api.myReservations(token);
        _reservations = res
          ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
      } catch (_) {
        _reservations = [];
      }

      // Count only the student's upcoming reservations.
      CampusEvent? featured;
      var upcomingCount = 0;

      final now = DateTime.now();
      for (final r in _reservations) {
        if (r.status != ReservationStatus.cancelled &&
            r.event.startsAt.isAfter(now)) {
          featured ??= r.event;
          upcomingCount++;
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
        _upcomingEventsCount = upcomingCount;
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
            // Purple Top Header matching screenshot
            _buildHeader(context, firstName, user?.picture),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),

                  // 3 Quick Stat Cards
                  Row(
                    children: [
                      CampusStatCard(
                        icon: Icons.calendar_today_outlined,
                        value: '$_upcomingEventsCount',
                        label: 'Upcoming Events',
                        onTap: widget.onOpenCalendar,
                      ),
                      const SizedBox(width: 10),
                      CampusStatCard(
                        icon: Icons.confirmation_num_outlined,
                        value:
                            '${_reservations.where((r) => r.status != ReservationStatus.cancelled).length}',
                        label: 'My Bookings',
                        onTap: widget.onOpenCalendar,
                      ),
                      const SizedBox(width: 10),
                      CampusStatCard(
                        icon: Icons.groups_outlined,
                        value: '$_totalClubs',
                        label: 'Campus Clubs',
                        onTap: widget.onOpenClubs,
                      ),
                    ],
                  ),

                  // Featured Event Card (if approved event discovered)
                  if (_featuredEvent != null) ...[
                    const SizedBox(height: 20),
                    _buildFeaturedCard(context, _featuredEvent!),
                  ],

                  const SizedBox(height: 24),

                  // My Upcoming Events Section
                  CampusSectionHeader(
                    title: 'My Upcoming Events',
                    icon: Icons.calendar_month_outlined,
                    actionLabel: 'View Calendar',
                    onAction: widget.onOpenCalendar,
                  ),
                  const SizedBox(height: 8),
                  _buildUpcomingEventsList(context),

                  const SizedBox(height: 26),

                  // Explore Clubs Section
                  CampusSectionHeader(
                    title: 'Explore Clubs',
                    icon: Icons.groups_outlined,
                    actionLabel: 'View All >',
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

  Widget _buildHeader(
    BuildContext context,
    String firstName,
    String? pictureUrl,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: CampusColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'CampusConnect',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
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
                  color: Colors.white,
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
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: ClipOval(
                  child: pictureUrl != null
                      ? UploadedImage(pictureUrl)
                      : Center(
                          child: Text(
                            firstName.isNotEmpty ? firstName[0] : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $firstName 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Discover clubs, events, and campus life',
                      style: TextStyle(
                        color: Color(0xFFECD6FC),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, CampusEvent event) {
    return Container(
      decoration: BoxDecoration(
        gradient: CampusColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33280747),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Color(0xFFFFD54F), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Featured Event',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatWeekday(event.startsAt)}, ${_formatMonthDay(event.startsAt)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _openEvent(event),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: CampusColors.purpleDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsList(BuildContext context) {
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
