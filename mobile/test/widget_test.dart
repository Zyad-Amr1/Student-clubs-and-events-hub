import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/core/storage/token_store.dart';
import 'package:campusconnect/features/auth/data/auth_repository.dart';
import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:campusconnect/features/clubs/data/clubs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('welcome navigation opens login and registration validation', (
    tester,
  ) async {
    final controller = createController(
      MemoryTokenStore(),
      MockClient((_) async => throw StateError('No request is expected.')),
    );
    await tester.pumpWidget(CampusConnectApp(authController: controller));
    await tester.pumpAndSettle();

    expect(find.text('CampusConnect'), findsOneWidget);
    expect(find.text('Find your people on campus.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('open-auth')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('open-auth')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('auth-email')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('auth-toggle-mode')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('registration-full-name')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('auth-submit')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Name must be between 2 and 120 characters.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'registration creates an account without inventing a login session',
    (tester) async {
      final tokenStore = MemoryTokenStore();
      late Map<String, dynamic> registrationBody;
      final controller = createController(
        tokenStore,
        MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/register');
          registrationBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(profileJson), 201);
        }),
      );
      await tester.pumpWidget(CampusConnectApp(authController: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('open-auth')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('auth-toggle-mode')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('registration-full-name')),
        'Student Name',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-email')),
        'student@example.edu',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('registration-university-id')),
        'U-103',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-password')),
        'correct-horse',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('registration-confirm-password')),
        'correct-horse',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('Account created. Please sign in to continue.'),
        findsOneWidget,
      );
      expect(registrationBody['confirm_password'], 'correct-horse');
      expect(tokenStore.value, isNull);
      expect(controller.isAuthenticated, isFalse);
    },
  );

  testWidgets('login opens live club discovery, details, profile, and logout', (
    tester,
  ) async {
    final tokenStore = MemoryTokenStore();
    final requestUris = <Uri>[];
    final controller = createController(
      tokenStore,
      MockClient((request) async {
        requestUris.add(request.url);
        switch (request.url.path) {
          case '/api/v1/auth/login':
            return http.Response(
              jsonEncode({
                'access_token': 'test-student-token',
                'token_type': 'bearer',
                'expires_in': 1800,
              }),
              200,
            );
          case '/api/v1/auth/me':
            return http.Response(jsonEncode(profileJson), 200);
          case '/api/v1/clubs':
            return http.Response(jsonEncode(clubPageJson), 200);
          case '/api/v1/clubs/club-uuid':
            return http.Response(jsonEncode(clubDetailsJson), 200);
          case '/api/v1/auth/logout':
            return http.Response('', 204);
          default:
            return http.Response(
              jsonEncode({'detail': 'Unexpected request'}),
              404,
            );
        }
      }),
    );
    await tester.pumpWidget(CampusConnectApp(authController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('open-auth')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-email')),
      'student@example.edu',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-password')),
      'correct-horse',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Club discovery'), findsOneWidget);
    expect(find.text('Robotics Club'), findsOneWidget);
    expect(tokenStore.value, 'test-student-token');
    expect(requestUris.any((uri) => uri.path == '/api/v1/auth/me'), isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('club-category-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technology').last);
    await tester.pumpAndSettle();
    expect(
      requestUris.any(
        (uri) =>
            uri.path == '/api/v1/clubs' &&
            uri.queryParameters['category'] == 'Technology',
      ),
      isTrue,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('club-search')),
      'Robotics',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      requestUris.any(
        (uri) =>
            uri.path == '/api/v1/clubs' &&
            uri.queryParameters['search'] == 'Robotics',
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey<String>('club-club-uuid')));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('Build Night'), findsOneWidget);
    expect(find.text('Venue: Engineering Hall'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('open-profile')));
    await tester.pumpAndSettle();
    expect(find.text('student@example.edu'), findsOneWidget);
    expect(find.text('student'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('logout-button')));
    await tester.pumpAndSettle();

    expect(find.text('Find your people on campus.'), findsOneWidget);
    expect(tokenStore.value, isNull);
    expect(requestUris.any((uri) => uri.path == '/api/v1/auth/logout'), isTrue);
  });

  testWidgets('club API errors show a retry action instead of fake content', (
    tester,
  ) async {
    var clubRequests = 0;
    final controller = createController(
      MemoryTokenStore(),
      MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/auth/login':
            return http.Response(
              jsonEncode({
                'access_token': 'test-student-token',
                'token_type': 'bearer',
                'expires_in': 1800,
              }),
              200,
            );
          case '/api/v1/auth/me':
            return http.Response(jsonEncode(profileJson), 200);
          case '/api/v1/clubs':
            clubRequests++;
            return http.Response(
              jsonEncode({'detail': 'Service unavailable'}),
              503,
            );
          default:
            return http.Response('', 404);
        }
      }),
    );
    await tester.pumpWidget(CampusConnectApp(authController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('open-auth')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-email')),
      'student@example.edu',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-password')),
      'correct-horse',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Service unavailable'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('retry-club-load')),
      findsOneWidget,
    );
    expect(find.text('Robotics Club'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('retry-club-load')));
    await tester.pumpAndSettle();
    expect(clubRequests, 2);
  });

  testWidgets('club discovery can request the next API page', (tester) async {
    final tokenStore = MemoryTokenStore()..value = 'saved-student-token';
    final requestedPages = <int>[];
    final controller = createController(
      tokenStore,
      MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/auth/me':
            return http.Response(jsonEncode(profileJson), 200);
          case '/api/v1/clubs':
            final page = int.parse(request.url.queryParameters['page']!);
            requestedPages.add(page);
            final clubs = page == 1
                ? [(clubPageJson['clubs'] as List<Object>).first]
                : [
                    {
                      'id': 'music-club-uuid',
                      'name': 'Music Club',
                      'description': 'Make music together.',
                      'category': 'Arts',
                      'logo_url': null,
                    },
                  ];
            return http.Response(
              jsonEncode({
                'clubs': clubs,
                'page': page,
                'page_size': 100,
                'total': 101,
              }),
              200,
            );
          default:
            return http.Response('', 404);
        }
      }),
    );
    await tester.pumpWidget(CampusConnectApp(authController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Robotics Club'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('load-more-clubs')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('load-more-clubs')));
    await tester.pumpAndSettle();

    expect(requestedPages, [1, 2]);
    expect(find.text('Music Club'), findsOneWidget);
  });
}

AuthController createController(TokenStore tokenStore, http.Client client) {
  final apiClient = ApiClient(
    baseUrl: 'https://campus.example.test',
    client: client,
  );
  return AuthController(
    authRepository: AuthRepository(
      apiClient: apiClient,
      tokenStore: tokenStore,
    ),
    clubsRepository: ClubsRepository(apiClient: apiClient),
  );
}

const profileJson = <String, Object>{
  'id': 'a1c973fd-9bc7-4f81-95e2-0392408e94b6',
  'full_name': 'Student Name',
  'email': 'student@example.edu',
  'university_id': 'U-103',
  'account_type': 'student',
  'is_active': true,
  'created_at': '2026-11-20T10:30:00Z',
};

const clubPageJson = <String, Object>{
  'clubs': [
    {
      'id': 'club-uuid',
      'name': 'Robotics Club',
      'description': 'Build and learn together.',
      'category': 'Technology',
      'logo_url': null,
    },
  ],
  'page': 1,
  'page_size': 100,
  'total': 1,
};

const clubDetailsJson = <String, Object>{
  'club': {
    'id': 'club-uuid',
    'name': 'Robotics Club',
    'description': 'Build and learn together.',
    'category': 'Technology',
    'logo_url': null,
  },
  'events': [
    {
      'id': 'event-uuid',
      'title': 'Build Night',
      'description': 'An evening workshop.',
      'venue': 'Engineering Hall',
      'starts_at': '2027-03-01T18:00:00Z',
      'ends_at': '2027-03-01T20:00:00Z',
      'seat_capacity': 30,
    },
  ],
  'page': 1,
  'page_size': 20,
  'total': 1,
};

class MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String accessToken) async => value = accessToken;
}
