import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/clubs/presentation/interview_screens.dart';
import 'package:campusconnect/features/events/presentation/student_event_details_screen.dart';
import 'package:material_ui/material_ui.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  bool _loading = true;
  String? _error;
  List<EventReservation> _reservations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final session = StudentSessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reservations = await session.authenticated(
        session.api.myReservations,
      );
      if (!mounted) return;
      _reservations = reservations
        ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
    } on ApiFailure catch (error) {
      if (mounted) _error = error.message;
    } catch (_) {
      if (mounted) _error = 'Could not load your events. Please retry.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(CampusEvent event) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentEventDetailsScreen(event: event),
      ),
    );
    if (mounted && StudentSessionScope.of(context).signedIn) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!StudentSessionScope.of(context).signedIn) {
      return const ReservationSignInScreen();
    }
    final groups = <DateTime, List<EventReservation>>{};
    for (final reservation in _reservations) {
      final day = DateUtils.dateOnly(reservation.event.startsAt.toLocal());
      (groups[day] ??= []).add(reservation);
    }
    final formats = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events Calendar'),
        actions: [
          IconButton(
            tooltip: 'Interview Calendar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const InterviewAppointmentsScreen(),
              ),
            ),
            icon: const Icon(Icons.event_available_outlined),
          ),
          IconButton(
            tooltip: 'Refresh calendar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error case final error?) ...[
                      Text(error),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ] else if (groups.isEmpty)
                      const Text('You have no event reservations yet.'),
                    for (final MapEntry(key: day, value: reservations)
                        in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          formats.formatFullDate(day),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final reservation in reservations)
                        Card(
                          child: ListTile(
                            title: Text(reservation.event.title),
                            subtitle: Text(
                              '${formats.formatTimeOfDay(TimeOfDay.fromDateTime(reservation.event.startsAt.toLocal()))}'
                              ' · ${reservationLabel(reservation)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(reservation.event),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
