import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const clubId = '22222222-2222-4222-8222-222222222222';
const eventId = '33333333-3333-4333-8333-333333333333';

class WorkflowStore implements TokenStore, PortalPreferenceStore {
  WorkflowStore({this.portal = 'studentAffairs'});

  String? token = 'test-only-token';
  String? portal;

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
  }
}

class WorkflowTransport implements ApiTransport {
  WorkflowTransport({this.role = 'student_affairs'});

  final String role;
  final List<String> calls = [];
  final List<String?> bodies = [];
  final List<String> methods = [];
  bool denyReview = false;
  bool queueEmpty = false;

  Map<String, dynamic> event([String state = 'draft']) => {
    'id': eventId,
    'club_id': clubId,
    'title': 'AI Workshop',
    'description': 'Practical project session',
    'venue': 'Engineering Hall',
    'starts_at': '2030-12-10T12:00:00Z',
    'ends_at': null,
    'seat_capacity': 40,
    'approval_status': state,
    'is_published': state == 'approved',
  };

  @override
  Future<ApiReply> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    methods.add(method);
    calls.add(uri.path);
    bodies.add(body);
    if (uri.path == '/api/v1/auth/me') {
      return ApiReply(
        200,
        jsonEncode({
          'id': '11111111-1111-4111-8111-111111111111',
          'full_name': 'Campus Test User',
          'email': 'test@example.edu',
          'university_id': 'TEST-1',
          'account_type': role,
        }),
      );
    }
    if (uri.path == '/api/v1/auth/student-affairs') {
      return const ApiReply(200, '{"account_type":"student_affairs"}');
    }
    if (uri.path == '/api/v1/auth/club-admin/clubs') {
      return const ApiReply(
        200,
        '{"clubs":[{"id":"22222222-2222-4222-8222-222222222222","name":"Robotics Club"}]}',
      );
    }
    if (uri.path == '/api/v1/student-affairs/events/pending') {
      return ApiReply(
        200,
        jsonEncode({
          'events': queueEmpty ? [] : [event('pending')],
          'total': queueEmpty ? 0 : 1,
          'page': 1,
          'page_size': 20,
        }),
      );
    }
    if (uri.path == '/api/v1/clubs/$clubId/events' && method == 'POST') {
      return ApiReply(201, jsonEncode(event()));
    }
    if (uri.path == '/api/v1/clubs/$clubId/events/$eventId/submit') {
      return ApiReply(200, jsonEncode(event('pending')));
    }
    if (uri.path == '/api/v1/student-affairs/events/$eventId/review') {
      if (denyReview) {
        return const ApiReply(403, '{"detail":"Insufficient permissions"}');
      }
      final decision = (jsonDecode(body!) as Map<String, dynamic>)['decision'];
      queueEmpty = true;
      return ApiReply(
        200,
        jsonEncode(event(decision == 'approve' ? 'approved' : 'rejected')),
      );
    }
    if (uri.path == '/api/v1/auth/logout') return const ApiReply(204, '');
    return const ApiReply(404, '{"detail":"Not found"}');
  }
}

CampusApi workflowApi(WorkflowTransport transport) =>
    CampusApi(transport: transport, baseUri: Uri.parse('http://10.0.2.2:8000'));

void main() {
  test(
    'Club Admin draft/submit uses real API paths, JWT and no publish fields',
    () async {
      final transport = WorkflowTransport(role: 'student');
      final api = workflowApi(transport);
      final result = await api.createDraftEvent(
        token: 'test-only-token',
        clubId: clubId,
        title: ' AI Workshop ',
        description: 'Practical project session',
        venue: 'Engineering Hall',
        startsAt: DateTime.utc(2030, 12, 10, 12),
        seatCapacity: 40,
      );
      expect(result.approvalStatus, 'draft');
      expect(result.isPublished, false);
      expect(transport.calls.last, '/api/v1/clubs/$clubId/events');
      final posted = jsonDecode(transport.bodies.last!) as Map<String, dynamic>;
      expect(posted['title'], 'AI Workshop');
      expect(posted['starts_at'], '2030-12-10T12:00:00.000Z');
      expect(posted.containsKey('approval_status'), false);
      expect(posted.containsKey('is_published'), false);

      final submitted = await api.submitDraftEvent(
        'test-only-token',
        clubId,
        eventId,
      );
      expect(submitted.approvalStatus, 'pending');
      expect(submitted.isPublished, false);
      expect(
        transport.calls.last,
        '/api/v1/clubs/$clubId/events/$eventId/submit',
      );
      expect(transport.bodies.last, isNull);
    },
  );

  test('Affairs queue and decisions use pending API contract', () async {
    final transport = WorkflowTransport();
    final api = workflowApi(transport);
    final page = await api.pendingEventReviews('test-only-token');
    expect(page.total, 1);
    expect(page.events.single.approvalStatus, 'pending');
    expect(transport.calls.last, '/api/v1/student-affairs/events/pending');
    final approved = await api.reviewEvent(
      'test-only-token',
      eventId,
      decision: 'approve',
    );
    expect(approved.approvalStatus, 'approved');
    expect(approved.isPublished, true);
    expect(jsonDecode(transport.bodies.last!)['decision'], 'approve');
    expect(
      transport.calls.last,
      '/api/v1/student-affairs/events/$eventId/review',
    );
  });

  test(
    'Affairs rejects events without publishing and handles denial',
    () async {
      final transport = WorkflowTransport();
      final api = workflowApi(transport);
      final rejected = await api.reviewEvent(
        'test-only-token',
        eventId,
        decision: 'reject',
      );
      expect(rejected.approvalStatus, 'rejected');
      expect(rejected.isPublished, false);
      transport.denyReview = true;
      await expectLater(
        api.reviewEvent('test-only-token', eventId, decision: 'approve'),
        throwsA(isA<ApiFailure>().having((e) => e.statusCode, 'status', 403)),
      );
      await expectLater(
        api.reviewEvent('test-only-token', eventId, decision: 'publish'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  testWidgets('Club Admin opens draft editor from verified managed club', (
    tester,
  ) async {
    final transport = WorkflowTransport(role: 'student');
    await tester.pumpWidget(
      CampusConnectApp(
        api: workflowApi(transport),
        tokenStore: WorkflowStore(portal: 'clubAdmin'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Robotics Club'), findsOneWidget);
    await tester.tap(find.text('Robotics Club'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft-title')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-draft')));
    await tester.pumpAndSettle();
    expect(find.text('Required field'), findsWidgets);
    expect(transport.calls, isNot(contains('/api/v1/clubs/$clubId/events')));
  });

  testWidgets('Affairs sees pending queue and approves through backend', (
    tester,
  ) async {
    final transport = WorkflowTransport();
    await tester.pumpWidget(
      CampusConnectApp(
        api: workflowApi(transport),
        tokenStore: WorkflowStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-pending-review')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pending-event-$eventId')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('approve-$eventId')));
    await tester.pumpAndSettle();
    expect(find.textContaining('approved and published'), findsOneWidget);
    expect(find.text('No pending events to review.'), findsOneWidget);
    expect(
      transport.calls,
      contains('/api/v1/student-affairs/events/$eventId/review'),
    );
  });

  testWidgets('Affairs errors are visible and not treated as approval', (
    tester,
  ) async {
    final transport = WorkflowTransport()..denyReview = true;
    await tester.pumpWidget(
      CampusConnectApp(
        api: workflowApi(transport),
        tokenStore: WorkflowStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-pending-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approve-$eventId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pending-event-$eventId')),
      findsOneWidget,
    );
  });
}
