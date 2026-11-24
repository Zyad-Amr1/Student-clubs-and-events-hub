import 'dart:convert';

import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordedCall {
  RecordedCall(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

class FakeApiTransport implements ApiTransport {
  FakeApiTransport(this.onSend);

  final ApiReply Function(RecordedCall call) onSend;
  final List<RecordedCall> calls = [];

  @override
  Future<ApiReply> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final call = RecordedCall(method, uri, headers, body);
    calls.add(call);
    return onSend(call);
  }
}

class MemoryTokenStore implements TokenStore {
  String? token;
  int deletions = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    deletions++;
    token = null;
  }
}

final profileJson = <String, dynamic>{
  'id': '11111111-1111-4111-8111-111111111111',
  'full_name': 'Student Example',
  'email': 'student@example.edu',
  'university_id': 'STU-001',
  'account_type': 'student',
  'is_active': true,
  'created_at': '2026-11-24T12:00:00+00:00',
};

const clubId = '22222222-2222-4222-8222-222222222222';

final clubJson = <String, dynamic>{
  'id': clubId,
  'name': 'Backend Robotics Society',
  'description': 'Built by student makers',
  'category': 'Academic',
  'logo_url': null,
};

ApiReply ok(Object body, [int code = 200]) => ApiReply(code, jsonEncode(body));

void main() {
  test(
    'registration sends only valid backend fields and does not create a JWT',
    () async {
      final fake = FakeApiTransport(
        (call) => ok({...profileJson, 'account_type': 'student'}, 201),
      );
      final api = CampusApi(
        transport: fake,
        baseUri: Uri.parse('http://10.0.2.2:8000'),
      );
      await api.register(
        fullName: 'Student Example',
        email: 'student@example.edu',
        universityId: 'STU-001',
        password: 'SecurePassphrase#123',
        confirmPassword: 'SecurePassphrase#123',
      );
      final call = fake.calls.single;
      expect(call.method, 'POST');
      expect(call.uri.path, '/api/v1/auth/register');
      final payload = jsonDecode(call.body!) as Map<String, dynamic>;
      expect(payload.keys.toSet(), {
        'full_name',
        'email',
        'university_id',
        'password',
        'confirm_password',
      });
      expect(payload.containsKey('account_type'), false);
      expect(payload.containsKey('access_token'), false);
    },
  );

  test(
    'login stores the JWT only after the server authorizes a Student',
    () async {
      final fake = FakeApiTransport((call) {
        if (call.uri.path.endsWith('/login')) {
          return ok({
            'access_token': 'test-jwt-value',
            'token_type': 'bearer',
            'expires_in': 3600,
          });
        }
        if (call.uri.path.endsWith('/me')) return ok(profileJson);
        return ok({});
      });
      final store = MemoryTokenStore();
      final session = StudentSession(
        api: CampusApi(
          transport: fake,
          baseUri: Uri.parse('http://10.0.2.2:8000'),
        ),
        store: store,
      );
      await session.signIn('student@example.edu', 'SecurePassphrase#123');
      expect(session.signedIn, isTrue);
      expect(store.token, 'test-jwt-value');
      expect(session.profile?.fullName, 'Student Example');
      expect(fake.calls.last.headers['Authorization'], 'Bearer test-jwt-value');
      await session.logout();
      expect(store.token, isNull);
      expect(session.signedIn, isFalse);
      expect(fake.calls.last.uri.path, '/api/v1/auth/logout');
      session.dispose();
    },
  );

  test('restore removes revoked JWT and does not authenticate', () async {
    final store = MemoryTokenStore()..token = 'revoked';
    final fake = FakeApiTransport(
      (call) => ok({'detail': 'Invalid or expired session'}, 401),
    );
    final session = StudentSession(
      api: CampusApi(
        transport: fake,
        baseUri: Uri.parse('http://10.0.2.2:8000'),
      ),
      store: store,
    );
    await session.restore();
    expect(session.ready, true);
    expect(session.signedIn, false);
    expect(store.token, null);
    expect(store.deletions, 1);
    session.dispose();
  });

  test(
    'non-Student roles never receive a locally authorized session',
    () async {
      final store = MemoryTokenStore();
      final fake = FakeApiTransport(
        (call) => call.uri.path.endsWith('/login')
            ? ok({
                'access_token': 'affairs-token',
                'token_type': 'bearer',
                'expires_in': 3600,
              })
            : call.uri.path.endsWith('/me')
            ? ok({...profileJson, 'account_type': 'student_affairs'})
            : ok({}),
      );
      final session = StudentSession(
        api: CampusApi(
          transport: fake,
          baseUri: Uri.parse('http://10.0.2.2:8000'),
        ),
        store: store,
      );
      await expectLater(
        session.signIn('student@example.edu', 'password'),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      expect(store.token, isNull);
      expect(session.signedIn, false);
      session.dispose();
    },
  );

  test(
    'club requests use the real read-only contract with bearer auth',
    () async {
      final fake = FakeApiTransport((call) {
        if (call.uri.path == '/api/v1/clubs') {
          return ok({
            'clubs': [clubJson],
            'page': 1,
            'page_size': 20,
            'total': 1,
          });
        }
        return ok({
          'club': clubJson,
          'events': [
            {
              'id': '33333333-3333-4333-8333-333333333333',
              'title': 'Approved backend event',
              'description': 'Only server-authorized events',
              'venue': 'Engineering Hall',
              'starts_at': '2030-03-01T13:30:00+00:00',
              'ends_at': null,
              'seat_capacity': 25,
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        });
      });
      final api = CampusApi(
        transport: fake,
        baseUri: Uri.parse('http://10.0.2.2:8000'),
      );
      final listing = await api.clubs('mock-jwt');
      expect(listing.clubs.single.name, 'Backend Robotics Society');
      expect(listing.total, 1);
      final details = await api.clubDetails('mock-jwt', clubId);
      expect(details.events.single.title, 'Approved backend event');
      expect(details.events.single.seatCapacity, 25);
      expect(fake.calls[0].uri.queryParameters, {
        'page': '1',
        'page_size': '20',
      });
      expect(fake.calls[1].uri.path, '/api/v1/clubs/$clubId');
      expect(fake.calls[1].headers['Authorization'], 'Bearer mock-jwt');
      expect(
        fake.calls.every(
          (call) => !call.uri.queryParameters.containsKey('search'),
        ),
        true,
      );
    },
  );

  test(
    '401 from an authenticated club request clears local credentials',
    () async {
      final store = MemoryTokenStore()..token = 'old-token';
      final fake = FakeApiTransport((call) {
        if (call.uri.path == '/api/v1/auth/me') return ok(profileJson);
        return ok({'detail': 'Invalid or expired session'}, 401);
      });
      final session = StudentSession(
        api: CampusApi(
          transport: fake,
          baseUri: Uri.parse('http://10.0.2.2:8000'),
        ),
        store: store,
      );
      await session.restore();
      await expectLater(
        session.authenticated((token) => session.api.clubs(token)),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(store.token, isNull);
      expect(session.signedIn, false);
      session.dispose();
    },
  );

  test('rejects unauthorized HTTP hosts before credentials leave the app',
      () async {
    final fake = FakeApiTransport((call) => ok({}));
    for (final host in [
      'http://192.168.1.10:8000',
      'http://example.org:8000',
      'http://10.0.2.2.attacker.example:8000',
    ]) {
      final api = CampusApi(
        transport: fake,
        baseUri: Uri.parse(host),
      );
      await expectLater(
        api.login('student@example.edu', 'private-password'),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        api.clubs('private-bearer-token'),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(fake.calls, isEmpty);
  });

  test('accepts HTTPS configured backend with credentials', () async {
    final fake = FakeApiTransport(
      (call) => ok({
        'access_token': 'test-jwt',
        'token_type': 'bearer',
        'expires_in': 3600,
      }),
    );
    final api = CampusApi(
      transport: fake,
      baseUri: Uri.parse('https://campus.example.test'),
    );
    expect(await api.login('student@example.edu', 'demo-password'), 'test-jwt');
    expect(fake.calls.single.uri.scheme, 'https');
  });

  test(
    'FastAPI validation errors are surfaced without exposing request payload',
    () async {
      final fake = FakeApiTransport(
        (call) => ok({
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'Invalid email address',
            },
          ],
        }, 422),
      );
      final api = CampusApi(
        transport: fake,
        baseUri: Uri.parse('http://10.0.2.2:8000'),
      );
      await expectLater(
        api.login('bad-email', 'sensitive-password'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            'Invalid email address',
          ),
        ),
      );
    },
  );
}
