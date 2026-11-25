import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class _MockTransport implements ApiTransport {
  _MockTransport({
    this.empty = false,
    this.browseFails = false,
    this.multiPage = false,
  });
  final bool empty;
  final bool browseFails;
  final bool multiPage;
  final browseQueries = <Map<String, String>>[];
  final List<String> paths = [];

  @override
  Future<ApiReply> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    paths.add(uri.path);
    if (uri.path.endsWith('/register')) {
      return ApiReply(
        201,
        jsonEncode({
          'id': '11111111-1111-4111-8111-111111111111',
          'full_name': 'Student User',
          'email': 'student@example.edu',
          'university_id': 'S-001',
          'account_type': 'student',
          'is_active': true,
          'created_at': '2026-11-24T12:00:00Z',
        }),
      );
    }
    if (uri.path.endsWith('/login')) {
      return const ApiReply(
        200,
        '{"access_token":"fake-jwt","token_type":"bearer","expires_in":3600}',
      );
    }
    if (uri.path.endsWith('/me')) {
      return const ApiReply(
        200,
        '{"id":"11111111-1111-4111-8111-111111111111","full_name":"Student User","email":"student@example.edu","university_id":"S-001","account_type":"student","is_active":true,"created_at":"2026-11-24T12:00:00Z"}',
      );
    }
    if (uri.path.endsWith('/logout')) return const ApiReply(204, '');
    if (uri.path == '/api/v1/clubs') {
      final query = uri.queryParameters;
      browseQueries.add(query);
      if (multiPage) {
        final page = int.parse(query['page']!);
        final filtered =
            query['search'] == 'Music' && query['category'] == 'Arts';
        final names = filtered
            ? ['Music Society', 'Music Workshop']
            : ['Mock Campus Engineering Club', 'Music Society'];
        return ApiReply(
          200,
          jsonEncode({
            'clubs': [
              {
                'id': names[page - 1],
                'name': names[page - 1],
                'description': 'Backend result',
                'category': filtered || page == 2 ? 'Arts' : 'Academic',
                'logo_url': null,
              },
            ],
            'page': page,
            'page_size': 20,
            'total': 2,
          }),
        );
      }
      if (browseFails) {
        return const ApiReply(503, '{"detail":"Database unavailable"}');
      }
      if (empty) {
        return const ApiReply(
          200,
          '{"clubs":[],"page":1,"page_size":20,"total":0}',
        );
      }
      return const ApiReply(
        200,
        '{"clubs":[{"id":"22222222-2222-4222-8222-222222222222","name":"Mock Campus Engineering Club","description":"Backend returned club","category":"Academic","logo_url":null}],"page":1,"page_size":20,"total":1}',
      );
    }
    if (uri.path.startsWith('/api/v1/clubs/')) {
      return const ApiReply(
        200,
        '{"club":{"id":"22222222-2222-4222-8222-222222222222","name":"Mock Campus Engineering Club","description":"Backend returned club","category":"Academic","logo_url":null},"events":[{"id":"33333333-3333-4333-8333-333333333333","title":"Published Event From API","description":"Approved by Student Affairs","venue":"Main Hall","starts_at":"2030-05-10T12:00:00+00:00","ends_at":null,"seat_capacity":50}],"page":1,"page_size":20,"total":1}',
      );
    }
    return const ApiReply(404, '{"detail":"Not found"}');
  }
}

CampusConnectApp _app(_MockTransport transport, _MemoryStore store) =>
    CampusConnectApp(
      api: CampusApi(
        transport: transport,
        baseUri: Uri.parse('http://10.0.2.2:8000'),
      ),
      tokenStore: store,
    );

Future<void> _login(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-auth')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('auth-email')),
    'student@example.edu',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password')),
    'StrongPassphrase#123',
  );
  await tester.tap(find.byKey(const ValueKey('auth-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome navigates to real sign-in, not placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_MockTransport(), _MemoryStore()));
    await tester.pumpAndSettle();
    expect(find.text('Your campus community starts here.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-auth')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('register leads to login, clubs, details, profile and logout', (
    tester,
  ) async {
    final backend = _MockTransport();
    final store = _MemoryStore();
    await tester.pumpWidget(_app(backend, store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-auth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('register-name')),
      'Student User',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'student@example.edu',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-university-id')),
      'S-001',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPassphrase#123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'StrongPassphrase#123',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    expect(
      backend.paths.indexOf('/api/v1/auth/register'),
      lessThan(backend.paths.indexOf('/api/v1/auth/login')),
    );
    expect(store.token, 'fake-jwt');
    expect(find.text('Mock Campus Engineering Club'), findsOneWidget);
    await tester.tap(find.text('Mock Campus Engineering Club'));
    await tester.pumpAndSettle();
    expect(find.text('Published Event From API'), findsOneWidget);
    expect(
      find.text('No upcoming published events for this club.'),
      findsNothing,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Student User'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-logout')));
    await tester.pumpAndSettle();
    expect(store.token, isNull);
    expect(backend.paths, contains('/api/v1/auth/logout'));
    expect(find.text('Your campus community starts here.'), findsOneWidget);
  });

  testWidgets(
    'empty server result is clearly different from fabricated clubs',
    (tester) async {
      await tester.pumpWidget(
        _app(_MockTransport(empty: true), _MemoryStore()),
      );
      await tester.pumpAndSettle();
      await _login(tester);
      expect(
        find.text('No approved active clubs are available yet.'),
        findsOneWidget,
      );
      expect(find.text('Robotics Club'), findsNothing);
    },
  );

  testWidgets('API failures show an explicit retry state', (tester) async {
    await tester.pumpWidget(
      _app(_MockTransport(browseFails: true), _MemoryStore()),
    );
    await tester.pumpAndSettle();
    await _login(tester);
    expect(find.text('Database unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-clubs')), findsOneWidget);
  });

  testWidgets(
    'server search finds clubs beyond the loaded page and keeps filters on pagination',
    (tester) async {
      final backend = _MockTransport(multiPage: true);
      await tester.pumpWidget(_app(backend, _MemoryStore()));
      await tester.pumpAndSettle();
      await _login(tester);
      expect(find.text('Mock Campus Engineering Club'), findsOneWidget);
      expect(find.text('Music Society'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('club-search')),
        'Music',
      );
      await tester.enterText(
        find.byKey(const ValueKey('club-category-filter')),
        'Arts',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(backend.browseQueries.last, {
        'page': '1',
        'page_size': '20',
        'search': 'Music',
        'category': 'Arts',
      });
      expect(find.text('Music Society'), findsOneWidget);
      expect(find.text('Mock Campus Engineering Club'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('load-more-clubs')));
      await tester.pumpAndSettle();
      expect(backend.browseQueries.last, {
        'page': '2',
        'page_size': '20',
        'search': 'Music',
        'category': 'Arts',
      });
      expect(find.text('Music Workshop'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('club-search')), '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(backend.browseQueries.last['page'], '1');
    },
  );

  testWidgets('client validation prevents blank registration', (tester) async {
    await tester.pumpWidget(_app(_MockTransport(), _MemoryStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-auth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsWidgets);
  });
}
