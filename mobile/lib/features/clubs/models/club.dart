class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String? logoUrl;

  factory ClubSummary.fromJson(Map<String, dynamic> json) {
    return ClubSummary(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      description: _requiredString(json, 'description'),
      category: _requiredString(json, 'category'),
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class ClubPage {
  const ClubPage({
    required this.clubs,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<ClubSummary> clubs;
  final int page;
  final int pageSize;
  final int total;

  factory ClubPage.fromJson(Map<String, dynamic> json) {
    final clubs = json['clubs'];
    if (clubs is! List) throw const FormatException('Invalid clubs response.');
    return ClubPage(
      clubs: clubs
          .whereType<Map<String, dynamic>>()
          .map(ClubSummary.fromJson)
          .toList(growable: false),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 100,
      total: json['total'] as int? ?? clubs.length,
    );
  }
}

class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.startsAt,
    required this.seatCapacity,
    this.endsAt,
  });

  final String id;
  final String title;
  final String description;
  final String venue;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int seatCapacity;

  factory ClubEvent.fromJson(Map<String, dynamic> json) {
    return ClubEvent(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      venue: _requiredString(json, 'venue'),
      startsAt: DateTime.parse(_requiredString(json, 'starts_at')),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(_requiredString(json, 'ends_at')),
      seatCapacity: json['seat_capacity'] as int? ?? 0,
    );
  }
}

class ClubDetails {
  const ClubDetails({
    required this.club,
    required this.events,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final ClubSummary club;
  final List<ClubEvent> events;
  final int page;
  final int pageSize;
  final int total;

  factory ClubDetails.fromJson(Map<String, dynamic> json) {
    final club = json['club'];
    final events = json['events'];
    if (club is! Map<String, dynamic> || events is! List) {
      throw const FormatException('Invalid club details response.');
    }
    return ClubDetails(
      club: ClubSummary.fromJson(club),
      events: events
          .whereType<Map<String, dynamic>>()
          .map(ClubEvent.fromJson)
          .toList(growable: false),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      total: json['total'] as int? ?? events.length,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('The API response is missing "$key".');
  }
  return value;
}
