import 'dart:convert';

import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/features/clubs/presentation/club_head_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client_test.dart';
import 'interview_lifecycle_test.dart' show launch;

void main() {
  testWidgets(
    'Student applies and sees the locked vacancy and pending request',
    (tester) async {
      var pending = false;
      final transport = FakeApiTransport((call) {
        if (call.uri.path == '/api/v1/auth/me') return ok(profileJson);
        if (call.uri.path.endsWith('/head-vacancy')) {
          return ok({'availability': pending ? 'locked' : 'open'});
        }
        if (call.uri.path.endsWith('/me/club-head-requests')) {
          return ok({
            'requests': [
              if (pending)
                {
                  'club_id': clubId,
                  'club_name': clubJson['name'],
                  'status': 'pending',
                },
            ],
          });
        }
        expect(call.method, 'POST');
        expect(call.uri.path, '/api/v1/clubs/$clubId/head-requests');
        pending = true;
        return ok({}, 201);
      });
      await launch(
        tester,
        ClubHeadScreen(club: CampusClub.fromJson(clubJson)),
        transport,
      );
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply as Club Head'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    },
  );

  testWidgets(
    'Student Affairs rejection sends the entered reason and refreshes the queue',
    (tester) async {
      var rejected = false;
      final transport = FakeApiTransport((call) {
        if (call.uri.path == '/api/v1/auth/me') {
          return ok({...profileJson, 'account_type': 'student_affairs'});
        }
        if (call.uri.path == '/api/v1/auth/student-affairs') {
          return ok({'account_type': 'student_affairs'});
        }
        if (call.method == 'GET') {
          expect(call.uri.path, '/api/v1/student-affairs/club-head-requests');
          return ok({
            'requests': [
              if (!rejected)
                {
                  'id': 'application-1',
                  'club_name': 'Robotics',
                  'status': 'pending',
                  'applicant_name': 'Student Example',
                },
            ],
          });
        }
        expect(
          call.uri.path,
          '/api/v1/student-affairs/club-head-requests/application-1/decision',
        );
        expect(jsonDecode(call.body!), {
          'decision': 'reject',
          'reason': 'Provide more detail',
        });
        rejected = true;
        return ok({});
      });
      await launch(tester, const ClubHeadScreen(review: true), transport);
      await tester.tap(find.text('Robotics'));
      await tester.pumpAndSettle();
      expect(find.text('Applicant: Student Example'), findsOneWidget);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Reject request'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Provide more detail');
      await tester.pump();
      await tester.tap(find.text('Reject request'));
      await tester.pumpAndSettle();
      expect(find.text('No pending requests.'), findsOneWidget);
    },
  );
}
