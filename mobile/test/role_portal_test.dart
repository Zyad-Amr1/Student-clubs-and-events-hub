import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/portal_role.dart';
import 'package:campusconnect/core/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class PortalMemoryStore implements TokenStore, PortalPreferenceStore {
  String? token;
  String? portal;
  int clears = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<String?> readPortal() async => portal;

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> writePortal(String value) async {
    portal = value;
  }

  @override
  Future<void> clear() async {
    token = null;
    portal = null;
    clears++;
  }
}

class PortalTransport implements ApiTransport {
  PortalTransport({this.accountType = 'student'});

  String accountType;
  bool allowClub = true;
  bool allowAffairs = true;
  final List<String> paths = [];

  @override
  Future<ApiReply> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    paths.add(uri.path);
    if (uri.path == '/api/v1/auth/login') {
      return const ApiReply(
        200,
        '{"access_token":"test-portal-jwt","token_type":"bearer","expires_in":3600}',
      );
    }
    if (uri.path == '/api/v1/auth/me') {
      return ApiReply(
        200,
        jsonEncode({
          'id': '11111111-1111-4111-8111-111111111111',
          'full_name': 'Verified Campus User',
          'email': 'portal@example.edu',
          'university_id': 'P-001',
          'account_type': accountType,
          'is_active': true,
          'created_at': '2026-11-25T08:00:00Z',
        }),
      );
    }
    if (uri.path == '/api/v1/auth/club-admin/clubs') {
      return allowClub
          ? const ApiReply(
              200,
              '{"clubs":[{"id":"22222222-2222-4222-8222-222222222222","name":"Verified Robotics Club"}]}',
            )
          : const ApiReply(403, '{"detail":"Insufficient permissions"}');
    }
    if (uri.path == '/api/v1/auth/student-affairs') {
      return allowAffairs
          ? const ApiReply(200, '{"account_type":"student_affairs"}')
          : const ApiReply(403, '{"detail":"Insufficient permissions"}');
    }
    if (uri.path == '/api/v1/auth/logout') {
      return const ApiReply(204, '');
    }
    return const ApiReply(404, '{"detail":"Not found"}');
  }
}

CampusApi portalApi(PortalTransport backend) =>
    CampusApi(transport: backend, baseUri: Uri.parse('http://10.0.2.2:8000'));

void main() {
  test(
    'Student sign-in reuses existing identity check without admin API',
    () async {
      final backend = PortalTransport();
      final store = PortalMemoryStore();
      final session = StudentSession(api: portalApi(backend), store: store);
      await session.signIn('student@example.edu', 'password');
      expect(session.portal, PortalRole.student);
      expect(session.signedIn, true);
      expect(store.token, 'test-portal-jwt');
      expect(backend.paths, isNot(contains('/api/v1/auth/club-admin/clubs')));
      session.dispose();
    },
  );

  test(
    'Club Admin needs a Student account and verified assigned club',
    () async {
      final backend = PortalTransport();
      final store = PortalMemoryStore();
      final session = StudentSession(api: portalApi(backend), store: store);
      await session.signIn(
        'admin@example.edu',
        'password',
        portal: PortalRole.clubAdmin,
      );
      expect(session.portal, PortalRole.clubAdmin);
      expect(session.managedClubs.single.name, 'Verified Robotics Club');
      expect(store.portal, 'clubAdmin');
      expect(backend.paths, contains('/api/v1/auth/club-admin/clubs'));
      session.dispose();
    },
  );

  test('Student cannot enter Club Admin portal without membership', () async {
    final backend = PortalTransport()..allowClub = false;
    final store = PortalMemoryStore();
    final session = StudentSession(api: portalApi(backend), store: store);
    await expectLater(
      session.signIn(
        'student@example.edu',
        'password',
        portal: PortalRole.clubAdmin,
      ),
      throwsA(isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 403)),
    );
    expect(session.signedIn, false);
    expect(store.token, isNull);
    expect(backend.paths.last, '/api/v1/auth/logout');
    session.dispose();
  });

  test(
    'Student Affairs portal requires provisioned account and backend check',
    () async {
      final backend = PortalTransport(accountType: 'student_affairs');
      final store = PortalMemoryStore();
      final session = StudentSession(api: portalApi(backend), store: store);
      await session.signIn(
        'affairs@example.edu',
        'password',
        portal: PortalRole.studentAffairs,
      );
      expect(session.portal, PortalRole.studentAffairs);
      expect(session.managedClubs, isEmpty);
      expect(backend.paths, contains('/api/v1/auth/student-affairs'));
      session.dispose();
    },
  );

  test('Student cannot gain Student Affairs by selecting its login', () async {
    final backend = PortalTransport();
    final store = PortalMemoryStore();
    final session = StudentSession(api: portalApi(backend), store: store);
    await expectLater(
      session.signIn(
        'student@example.edu',
        'password',
        portal: PortalRole.studentAffairs,
      ),
      throwsA(isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 403)),
    );
    expect(store.token, isNull);
    expect(session.signedIn, false);
    session.dispose();
  });

  test(
    'Stored portal is reverified and revoked membership denies restoration',
    () async {
      final backend = PortalTransport()..allowClub = false;
      final store = PortalMemoryStore()
        ..token = 'saved-jwt'
        ..portal = 'clubAdmin';
      final session = StudentSession(api: portalApi(backend), store: store);
      await session.restore();
      expect(session.ready, true);
      expect(session.signedIn, false);
      expect(store.token, isNull);
      expect(store.clears, 1);
      session.dispose();
    },
  );

  test('Active club membership is revoked during refresh', () async {
    final backend = PortalTransport();
    final store = PortalMemoryStore();
    final session = StudentSession(api: portalApi(backend), store: store);
    await session.signIn(
      'admin@example.edu',
      'password',
      portal: PortalRole.clubAdmin,
    );
    backend.allowClub = false;
    await expectLater(
      session.refreshPortalAccess(),
      throwsA(isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 403)),
    );
    expect(session.signedIn, false);
    expect(store.token, isNull);
    session.dispose();
  });

  testWidgets('three portal choices route to separate secure login screens', (
    tester,
  ) async {
    final backend = PortalTransport();
    await tester.pumpWidget(
      CampusConnectApp(
        api: portalApi(backend),
        tokenStore: PortalMemoryStore(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-auth')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-club-admin-auth')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-student-affairs-auth')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open-club-admin-auth')));
    await tester.pumpAndSettle();
    expect(find.text('Club administrator login'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-toggle')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-student-affairs-auth')));
    await tester.pumpAndSettle();
    expect(find.text('Student Affairs login'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-toggle')), findsNothing);
  });

  testWidgets(
    'Club Admin login displays server-owned memberships and signs out',
    (tester) async {
      final backend = PortalTransport();
      final store = PortalMemoryStore();
      await tester.pumpWidget(
        CampusConnectApp(api: portalApi(backend), tokenStore: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-club-admin-auth')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'admin@example.edu',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'password',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Club Admin portal'), findsOneWidget);
      expect(find.text('Verified Robotics Club'), findsOneWidget);
      expect(store.portal, 'clubAdmin');
      await tester.tap(find.byKey(const ValueKey('role-logout')));
      await tester.pumpAndSettle();
      expect(store.token, isNull);
      expect(find.text('Your campus community starts here.'), findsOneWidget);
    },
  );

  testWidgets('Student Affairs portal needs server authorization', (
    tester,
  ) async {
    final backend = PortalTransport(accountType: 'student_affairs');
    await tester.pumpWidget(
      CampusConnectApp(
        api: portalApi(backend),
        tokenStore: PortalMemoryStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-student-affairs-auth')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'affairs@example.edu',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Student Affairs portal'), findsOneWidget);
    expect(find.text('Student Affairs access verified'), findsOneWidget);
    expect(find.text('Verified Robotics Club'), findsNothing);
  });
}
