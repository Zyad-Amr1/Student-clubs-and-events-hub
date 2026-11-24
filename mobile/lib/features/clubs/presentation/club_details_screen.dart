import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:campusconnect/features/clubs/models/club.dart';
import 'package:material_ui/material_ui.dart';

class ClubDetailsScreen extends StatefulWidget {
  const ClubDetailsScreen({
    super.key,
    required this.controller,
    required this.club,
  });

  final AuthController controller;
  final ClubSummary club;

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  late Future<ClubDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<ClubDetails> _loadDetails() {
    final token = widget.controller.sessionToken;
    if (token == null) {
      return Future<ClubDetails>.error(
        const ApiException('Sign in to view club details.'),
      );
    }
    return widget.controller.clubsRepository.details(
      clubId: widget.club.id,
      accessToken: token,
    );
  }

  void _retry() => setState(() => _detailsFuture = _loadDetails());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Club details')),
      body: FutureBuilder<ClubDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            final error = snapshot.error;
            final message = error is ApiException
                ? error.message
                : 'Could not load club details. Please try again.';
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
                      key: const ValueKey<String>('retry-club-details'),
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final details = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.groups_outlined,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                details.club.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text(details.club.category)),
              ),
              const SizedBox(height: 8),
              Text(
                details.club.description,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 28),
              Text(
                'Upcoming events',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (details.events.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'There are no upcoming events for this club yet.',
                    ),
                  ),
                )
              else
                ...details.events.map((event) {
                  final localStart = event.startsAt.toLocal();
                  final date = MaterialLocalizations.of(context)
                      .formatMediumDate(localStart);
                  final time = MaterialLocalizations.of(context)
                      .formatTimeOfDay(TimeOfDay.fromDateTime(localStart));
                  return Card(
                    key: ValueKey<String>('event-${event.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('$date · $time'),
                          const SizedBox(height: 4),
                          Text('Venue: ${event.venue}'),
                          Text('Capacity: ${event.seatCapacity}'),
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(event.description),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
