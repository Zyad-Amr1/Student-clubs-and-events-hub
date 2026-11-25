import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

String reservationLabel(EventReservation reservation) =>
    switch (reservation.status) {
      ReservationStatus.confirmed => 'Confirmed',
      ReservationStatus.waitlisted =>
        'Waitlisted · position ${reservation.waitlistPosition}',
      ReservationStatus.cancelled => 'Cancelled',
    };

String eventTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final formats = MaterialLocalizations.of(context);
  return '${formats.formatFullDate(local)} · '
      '${formats.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class StudentEventDetailsScreen extends StatefulWidget {
  const StudentEventDetailsScreen({required this.event, super.key});

  final CampusEvent event;

  @override
  State<StudentEventDetailsScreen> createState() =>
      _StudentEventDetailsScreenState();
}

class _StudentEventDetailsScreenState extends State<StudentEventDetailsScreen> {
  EventReservation? _reservation;
  bool _hasState = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() => _run();

  Future<void> _run({bool reserve = false, bool cancel = false}) async {
    final session = StudentSessionScope.of(context);
    final eventId = widget.event.id;
    setState(() {
      _busy = true;
      _error = null;
      _hasState = false;
    });
    try {
      if (reserve) {
        final result = await session.authenticated(
          (token) => session.api.reserveEvent(token, eventId),
        );
        if (!mounted) return;
        _reservation = result;
      } else {
        if (cancel) {
          await session.authenticated(
            (token) => session.api.cancelReservation(token, eventId),
          );
        }
        final reservations = await session.authenticated(
          session.api.myReservations,
        );
        if (!mounted) return;
        _reservation = null;
        for (final reservation in reservations) {
          if (reservation.event.id == eventId) {
            _reservation = reservation;
            break;
          }
        }
      }
      _hasState = true;
    } on ApiFailure catch (error) {
      if (!mounted) return;
      _error = error.message;
    } catch (_) {
      if (!mounted) return;
      _error = 'Could not update reservation status. Please retry.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel your place?'),
        content: const Text('This removes your reservation for this event.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep reservation'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true && !_busy) await _run(cancel: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!StudentSessionScope.of(context).signedIn) {
      return const ReservationSignInScreen();
    }
    final reservation = _reservation;
    final event = reservation?.event ?? widget.event;
    final hasStarted = !event.startsAt.isAfter(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        actions: [
          IconButton(
            tooltip: 'Refresh reservation',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CampusHeader(
              event.title,
              eventTime(context, event.startsAt),
              icon: Icons.event_outlined,
            ),
            const SizedBox(height: 8),
            if (event.cancelledAt != null)
              CampusFeedback(
                'Cancelled: ${event.cancellationReason ?? 'No reason provided'}',
                icon: Icons.error_outline,
              ),
            const SizedBox(height: 8),
            const CampusSectionHeader(title: 'Your reservation'),
            if (_busy)
              const LinearProgressIndicator()
            else if (_error case final error?)
              CampusFeedback(
                error,
                icon: Icons.error_outline,
                retry: _refresh,
                retryLabel: 'Retry status',
              ),
            if (!_busy && _error == null && _hasState)
              if (reservation != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: CampusStatus(reservationLabel(reservation)),
                ),
                const SizedBox(height: 8),
                if (reservation.status != ReservationStatus.cancelled)
                  OutlinedButton(
                    onPressed: _confirmCancellation,
                    child: const Text('Cancel reservation'),
                  ),
              ] else if (hasStarted)
                const CampusFeedback(
                  'Reservations are closed because the event has started.',
                )
              else
                FilledButton(
                  onPressed: () => _run(reserve: true),
                  child: const Text('Reserve a place'),
                ),
            const SizedBox(height: 12),
            const CampusSectionHeader(title: 'About this event'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    CampusDetailRow(Icons.place_outlined, 'Venue', event.venue),
                    CampusDetailRow(
                      Icons.schedule_outlined,
                      'Starts',
                      eventTime(context, event.startsAt),
                    ),
                    if (event.endsAt case final end?)
                      CampusDetailRow(
                        Icons.schedule_outlined,
                        'Ends',
                        eventTime(context, end),
                      ),
                    CampusDetailRow(
                      Icons.groups_outlined,
                      'Capacity',
                      '${event.seatCapacity}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReservationSignInScreen extends StatelessWidget {
  const ReservationSignInScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Student sign-in')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CampusHeader(
          'Your reservations',
          'Sign in with your campus account to manage your event reservations.',
          icon: Icons.confirmation_num_outlined,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.authentication, (route) => false),
          child: const Text('Sign in to view reservations'),
        ),
      ],
    ),
  );
}
