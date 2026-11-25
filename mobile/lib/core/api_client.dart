import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef JsonObject = Map<String, dynamic>;

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiReply {
  const ApiReply(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// Injectable transport makes the real HTTP contract independently testable.
abstract class ApiTransport {
  Future<ApiReply> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  });
}

class IoApiTransport implements ApiTransport {
  @override
  Future<ApiReply> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 12));
      // Do not follow redirects that could send credentials to another host.
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) {
        request.write(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12));
      return ApiReply(response.statusCode, text);
    } on SocketException {
      throw const ApiFailure(
        'Cannot connect to CampusConnect. Check the backend URL and network.',
      );
    } on HandshakeException {
      throw const ApiFailure('Secure connection to the backend failed.');
    } on HttpException {
      throw const ApiFailure('The backend connection failed.');
    } on IOException {
      throw const ApiFailure('The backend connection was interrupted.');
    } on TimeoutException {
      throw const ApiFailure('The backend did not respond. Please retry.');
    } finally {
      client.close(force: true);
    }
  }
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.universityId,
    required this.accountType,
    this.faculty,
    this.department,
    this.academicYear,
    this.picture,
  });

  final String id;
  final String fullName;
  final String email;
  final String universityId;
  final String accountType;
  final String? faculty;
  final String? department;
  final int? academicYear;
  final String? picture;

  factory StudentProfile.fromJson(JsonObject json) => StudentProfile(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    universityId: json['university_id'] as String,
    accountType: json['account_type'] as String,
    faculty: json['faculty'] as String?,
    department: json['department'] as String?,
    academicYear: json['academic_year'] as int?,
    picture: json['profile_picture_url'] as String?,
  );
}

class CampusClub {
  const CampusClub({
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

  factory CampusClub.fromJson(JsonObject json) => CampusClub(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    logoUrl: json['logo_url'] as String?,
  );
}

class ClubCreationRequest {
  const ClubCreationRequest({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.logoUrl,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String? logoUrl;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  bool get pending => status == 'pending';
  String get statusLabel => switch (status) {
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    'withdrawn' => 'Withdrawn',
    _ => 'Unknown',
  };

  factory ClubCreationRequest.fromJson(JsonObject json) => ClubCreationRequest(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    logoUrl: json['logo_url'] as String?,
    status: json['status'] as String,
    rejectionReason: json['rejection_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class CampusEvent {
  const CampusEvent({
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

  factory CampusEvent.fromJson(JsonObject json) => CampusEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    venue: json['venue'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: json['ends_at'] == null
        ? null
        : DateTime.parse(json['ends_at'] as String),
    seatCapacity: json['seat_capacity'] as int,
  );
}

enum ReservationStatus { confirmed, waitlisted }

class EventReservation {
  const EventReservation({
    required this.event,
    required this.status,
    required this.waitlistPosition,
  });

  final CampusEvent event;
  final ReservationStatus status;
  final int? waitlistPosition;

  factory EventReservation.fromJson(JsonObject json) {
    try {
      final event = CampusEvent.fromJson(json['event'] as JsonObject);
      final status = ReservationStatus.values.byName(json['status'] as String);
      final position = json['waitlist_position'] as int?;
      if (json['event_id'] != event.id ||
          (status == ReservationStatus.confirmed && position != null) ||
          (status == ReservationStatus.waitlisted &&
              (position == null || position < 1))) {
        throw const FormatException();
      }
      return EventReservation(
        event: event,
        status: status,
        waitlistPosition: position,
      );
    } on Object {
      throw const ApiFailure('Unexpected reservation response. Please retry.');
    }
  }
}

class ClubPage {
  const ClubPage({
    required this.clubs,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<CampusClub> clubs;
  final int page;
  final int pageSize;
  final int total;

  factory ClubPage.fromJson(JsonObject json) => ClubPage(
    clubs: (json['clubs'] as List<dynamic>)
        .map((item) => CampusClub.fromJson(item as JsonObject))
        .toList(),
    page: json['page'] as int,
    pageSize: json['page_size'] as int,
    total: json['total'] as int,
  );
}

class ClubDetails {
  const ClubDetails({
    required this.club,
    required this.events,
    required this.total,
  });

  final CampusClub club;
  final List<CampusEvent> events;
  final int total;

  factory ClubDetails.fromJson(JsonObject json) => ClubDetails(
    club: CampusClub.fromJson(json['club'] as JsonObject),
    events: (json['events'] as List<dynamic>)
        .map((item) => CampusEvent.fromJson(item as JsonObject))
        .toList(),
    total: json['total'] as int,
  );
}

class ManagedClub {
  const ManagedClub({required this.id, required this.name});

  final String id;
  final String name;

  factory ManagedClub.fromJson(JsonObject json) =>
      ManagedClub(id: json['id'] as String, name: json['name'] as String);
}

class ManagedEvent {
  const ManagedEvent({
    required this.id,
    required this.clubId,
    required this.title,
    required this.description,
    required this.venue,
    required this.startsAt,
    required this.seatCapacity,
    required this.approvalStatus,
    required this.isPublished,
  });

  final String id;
  final String clubId;
  final String title;
  final String description;
  final String venue;
  final DateTime startsAt;
  final int seatCapacity;
  final String approvalStatus;
  final bool isPublished;

  factory ManagedEvent.fromJson(JsonObject json) => ManagedEvent(
    id: json['id'] as String,
    clubId: json['club_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    venue: json['venue'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String),
    seatCapacity: json['seat_capacity'] as int,
    approvalStatus: json['approval_status'] as String,
    isPublished: json['is_published'] as bool,
  );
}

class PendingReviewPage {
  const PendingReviewPage({required this.events, required this.total});

  final List<ManagedEvent> events;
  final int total;

  factory PendingReviewPage.fromJson(JsonObject json) => PendingReviewPage(
    events: (json['events'] as List<dynamic>)
        .map((entry) => ManagedEvent.fromJson(entry as JsonObject))
        .toList(),
    total: json['total'] as int,
  );
}

class CampusApi {
  CampusApi({ApiTransport? transport, Uri? baseUri})
    : _transport = transport ?? IoApiTransport(),
      baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000',
            ),
          );

  final ApiTransport _transport;
  final Uri baseUri;

  Future<JsonObject> _request(
    String method,
    String path, {
    String? token,
    JsonObject? body,
    Map<String, String>? query,
  }) async {
    if (baseUri.host.isEmpty || !{'http', 'https'}.contains(baseUri.scheme)) {
      throw const ApiFailure('Configure a valid HTTP(S) API_BASE_URL.');
    }
    // dart:io HttpClient is not governed by Android's network security XML.
    // Only the Android Emulator host bridge may use plaintext HTTP.
    if (baseUri.scheme == 'http' &&
        (kReleaseMode || baseUri.host != '10.0.2.2')) {
      throw const ApiFailure(
        'HTTP is allowed only for Android Emulator at 10.0.2.2 in development. Use HTTPS elsewhere.',
      );
    }
    final uri = baseUri.replace(
      path: '${baseUri.path.replaceFirst(RegExp(r"/$"), "")}$path',
      queryParameters: query,
    );
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final reply = await _transport.send(
      method,
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    dynamic decoded;
    try {
      decoded = reply.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(reply.body);
    } on FormatException {
      throw const ApiFailure('Unexpected backend response.');
    }
    if (reply.statusCode < 200 || reply.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      String message = 'Request failed (HTTP ${reply.statusCode}).';
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty && detail.first is Map) {
        final error = detail.first as Map;
        message = error['msg']?.toString() ?? 'Please check your input.';
      }
      throw ApiFailure(message, statusCode: reply.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiFailure('Unexpected backend response.');
    }
    return decoded;
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String universityId,
    required String password,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/api/v1/auth/register',
      body: {
        'full_name': fullName,
        'email': email,
        'university_id': universityId,
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
  }

  Future<String> login(String email, String password) async {
    final json = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    final token = json['access_token'];
    if (token is! String || token.isEmpty || json['token_type'] != 'bearer') {
      throw const ApiFailure('Invalid sign-in response.');
    }
    return token;
  }

  Future<StudentProfile> profile(String token) async => StudentProfile.fromJson(
    await _request('GET', '/api/v1/auth/me', token: token),
  );

  Future<StudentProfile> updateProfile(String token, JsonObject data) async =>
      StudentProfile.fromJson(
        await _request('PUT', '/api/v1/auth/me', token: token, body: data),
      );

  Future<JsonObject> academicCatalog(String token) =>
      _request('GET', '/api/v1/auth/academic-catalog', token: token);

  Future<void> changePassword(String token, JsonObject data) async {
    await _request(
      'POST',
      '/api/v1/auth/me/password',
      token: token,
      body: data,
    );
  }

  Future<List<ManagedClub>> myManagedClubs(String token) async {
    final data = await _request(
      'GET',
      '/api/v1/auth/me/managed-clubs',
      token: token,
    );
    return (data['clubs'] as List)
        .cast<JsonObject>()
        .map(ManagedClub.fromJson)
        .toList();
  }

  Future<List<ManagedClub>> managedClubs(String token) async {
    final json = await _request(
      'GET',
      '/api/v1/auth/club-admin/clubs',
      token: token,
    );
    final clubs = json['clubs'];
    if (clubs is! List) {
      throw const ApiFailure('Invalid club permission response.');
    }
    return clubs
        .map((item) => ManagedClub.fromJson(item as JsonObject))
        .toList();
  }

  Future<void> verifyStudentAffairs(String token) async {
    final response = await _request(
      'GET',
      '/api/v1/auth/student-affairs',
      token: token,
    );
    if (response['account_type'] != 'student_affairs') {
      throw const ApiFailure('Insufficient permissions.', statusCode: 403);
    }
  }

  Future<void> logout(String token) async {
    await _request('POST', '/api/v1/auth/logout', token: token);
  }

  Future<ManagedEvent> createDraftEvent({
    required String token,
    required String clubId,
    required String title,
    required String description,
    required String venue,
    required DateTime startsAt,
    required int seatCapacity,
  }) async {
    final json = await _request(
      'POST',
      '/api/v1/clubs/${Uri.encodeComponent(clubId)}/events',
      token: token,
      body: {
        'title': title.trim(),
        'description': description.trim(),
        'venue': venue.trim(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'seat_capacity': seatCapacity,
      },
    );
    return ManagedEvent.fromJson(json);
  }

  Future<ManagedEvent> submitDraftEvent(
    String token,
    String clubId,
    String eventId,
  ) async {
    final json = await _request(
      'POST',
      '/api/v1/clubs/${Uri.encodeComponent(clubId)}/events/${Uri.encodeComponent(eventId)}/submit',
      token: token,
    );
    return ManagedEvent.fromJson(json);
  }

  Future<PendingReviewPage> pendingEventReviews(
    String token, {
    int page = 1,
  }) async {
    final json = await _request(
      'GET',
      '/api/v1/student-affairs/events/pending',
      token: token,
      query: {'page': '$page', 'page_size': '20'},
    );
    return PendingReviewPage.fromJson(json);
  }

  Future<ManagedEvent> reviewEvent(
    String token,
    String eventId, {
    required String decision,
  }) async {
    if (decision != 'approve' && decision != 'reject') {
      throw const ApiFailure('Invalid event review decision.');
    }
    final json = await _request(
      'POST',
      '/api/v1/student-affairs/events/${Uri.encodeComponent(eventId)}/review',
      token: token,
      body: {'decision': decision},
    );
    return ManagedEvent.fromJson(json);
  }

  Future<List<EventReservation>> myReservations(String token) async {
    final json = await _request('GET', '/api/v1/me/reservations', token: token);
    final reservations = json['reservations'];
    if (reservations is! List ||
        reservations.any((item) => item is! JsonObject)) {
      throw const ApiFailure('Unexpected reservation response. Please retry.');
    }
    return reservations
        .cast<JsonObject>()
        .map(EventReservation.fromJson)
        .toList();
  }

  String _reservationPath(String eventId) =>
      '/api/v1/events/${Uri.encodeComponent(eventId)}/reservations';

  Future<EventReservation> reserveEvent(String token, String eventId) async {
    final result = EventReservation.fromJson(
      await _request('POST', _reservationPath(eventId), token: token),
    );
    if (result.event.id != eventId) {
      throw const ApiFailure('Unexpected reservation response. Please retry.');
    }
    return result;
  }

  Future<void> cancelReservation(String token, String eventId) async {
    await _request('DELETE', _reservationPath(eventId), token: token);
  }

  Future<ClubPage> clubs(
    String token, {
    int page = 1,
    String search = '',
    String category = '',
  }) async {
    final json = await _request(
      'GET',
      '/api/v1/clubs',
      token: token,
      query: {
        'page': '$page',
        'page_size': '20',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (category.trim().isNotEmpty) 'category': category.trim(),
      },
    );
    return ClubPage.fromJson(json);
  }

  static const _myClubRequests = '/api/v1/me/club-requests';
  static const _reviewClubRequests = '/api/v1/student-affairs/club-requests';

  Future<({List<ClubCreationRequest> requests, bool hasMore})> clubRequests(
    String token, {
    required bool review,
    required int page,
  }) async {
    final json = await _request(
      'GET',
      review ? _reviewClubRequests : _myClubRequests,
      token: token,
      query: {'page': '$page'},
    );
    return (
      requests: (json['requests'] as List)
          .cast<JsonObject>()
          .map(ClubCreationRequest.fromJson)
          .toList(),
      hasMore: json['has_more'] as bool,
    );
  }

  Future<void> saveClubRequest(
    String token,
    JsonObject data, {
    String? id,
  }) async {
    await _request(
      id == null ? 'POST' : 'PUT',
      id == null
          ? _myClubRequests
          : '$_myClubRequests/${Uri.encodeComponent(id)}',
      token: token,
      body: data,
    );
  }

  Future<void> withdrawClubRequest(String token, String id) async {
    await _request(
      'POST',
      '$_myClubRequests/${Uri.encodeComponent(id)}/withdraw',
      token: token,
    );
  }

  Future<List<CampusClub>> similarClubs(String token, String id) async {
    final json = await _request(
      'GET',
      '$_reviewClubRequests/${Uri.encodeComponent(id)}/similar',
      token: token,
    );
    return (json['clubs'] as List)
        .cast<JsonObject>()
        .map(CampusClub.fromJson)
        .toList();
  }

  Future<void> decideClubRequest(
    String token,
    String id,
    String decision, {
    String? reason,
  }) async {
    await _request(
      'POST',
      '$_reviewClubRequests/${Uri.encodeComponent(id)}/decision',
      token: token,
      body: {'decision': decision, 'reason': ?reason},
    );
  }

  String _managedClubPath(String id) =>
      '/api/v1/club-admin/clubs/${Uri.encodeComponent(id)}/profile';

  Future<CampusClub> managedClubProfile(String token, String id) async =>
      CampusClub.fromJson(
        await _request('GET', _managedClubPath(id), token: token),
      );

  Future<void> updateManagedClub(
    String token,
    String id,
    JsonObject data,
  ) async {
    await _request('PUT', _managedClubPath(id), token: token, body: data);
  }

  Future<ClubDetails> clubDetails(
    String token,
    String clubId, {
    int page = 1,
  }) async {
    final json = await _request(
      'GET',
      '/api/v1/clubs/${Uri.encodeComponent(clubId)}',
      token: token,
      query: {'page': '$page', 'page_size': '20'},
    );
    return ClubDetails.fromJson(json);
  }
}
