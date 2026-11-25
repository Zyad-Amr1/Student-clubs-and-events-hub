import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client_test.dart';

void main() {
  testWidgets('Student Profile submits a club request and shows its history', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    final transport = FakeApiTransport((call) {
      expect(call.headers['Authorization'], 'Bearer student-test-token');
      switch ((call.method, call.uri.path)) {
        case ('GET', '/api/v1/auth/me'):
          return ok(profileJson);
        case ('GET', '/api/v1/clubs'):
          return ok({'clubs': [], 'page': 1, 'page_size': 20, 'total': 0});
        case ('GET', '/api/v1/auth/me/managed-clubs'):
          return ok({'clubs': []});
        case ('GET', '/api/v1/me/club-requests'):
          return ok({'requests': requests, 'has_more': false});
        case ('POST', '/api/v1/me/club-requests'):
          final fields = jsonDecode(call.body!) as Map<String, dynamic>;
          expect(fields, {
            'name': 'Space Club',
            'description': 'Stargazing',
            'category': 'Science',
          });
          requests.add({
            ...fields,
            'id': 'request-1',
            'status': 'pending',
            'created_at': '2026-11-25T09:00:00Z',
            'rejection_reason': null,
            'logo_url': null,
          });
          return ok(requests.single, 201);
        default:
          fail('Unexpected request: ${call.method} ${call.uri.path}');
      }
    });

    await tester.pumpWidget(
      CampusConnectApp(
        api: CampusApi(transport: transport),
        tokenStore: MemoryTokenStore()..token = 'student-test-token',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Manage My Club'), findsNothing);
    final myRequests = find.text('My Club Requests');
    await tester.ensureVisible(myRequests);
    await tester.pumpAndSettle();
    await tester.tap(myRequests);
    await tester.pumpAndSettle();
    expect(find.text('You have no club requests yet.'), findsOneWidget);
    await tester.tap(find.text('Request a New Club'));
    await tester.pumpAndSettle();
    for (final entry in {
      'Club name': 'Space Club',
      'Description': 'Stargazing',
      'Category': 'Science',
    }.entries) {
      await tester.enterText(
        find.widgetWithText(TextFormField, entry.key),
        entry.value,
      );
    }
    final submit = find.text('Submit request');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Space Club'), findsOneWidget);
    expect(find.text('Pending · Science'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
  });
}
