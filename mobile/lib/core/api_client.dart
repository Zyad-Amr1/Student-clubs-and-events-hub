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
  });

  final String id;
  final String fullName;
  final String email;
  final String universityId;
  final String accountType;

  factory StudentProfile.fromJson(JsonObject json) => StudentProfile(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    universityId: json['university_id'] as String,
    accountType: json['account_type'] as String,
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
    if (baseUri.host.isEmpty ||
        !{'http', 'https'}.contains(baseUri.scheme)) {
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

  Future<void> logout(String token) async {
    await _request('POST', '/api/v1/auth/logout', token: token);
  }

  Future<ClubPage> clubs(String token, {int page = 1}) async {
    final json = await _request(
      'GET',
      '/api/v1/clubs',
      token: token,
      query: {'page': '$page', 'page_size': '20'},
    );
    return ClubPage.fromJson(json);
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
