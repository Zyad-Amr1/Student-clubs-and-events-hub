import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:campusconnect/features/clubs/presentation/interview_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client_test.dart';

void main() {
  testWidgets('student selects a day and sees a time only after publication', (
    tester,
  ) async {
    const date = '2031-02-02';
    const path = '/api/v1/me/applications/application-1/interview';
    final application = MembershipApplication.fromJson({
      'id': 'application-1',
      'club_id': clubId,
      'club_name': 'Robotics Club',
      'applicant_name': 'Student',
      'status': 'interview_required',
      'submitted_at': '2030-12-20T10:00:00Z',
    });
    var selected = false;
    var published = false;
    final transport = FakeApiTransport((request) {
      expect(request.headers['Authorization'], 'Bearer interview-token');
      switch ((request.method, request.uri.path)) {
        case ('GET', '/api/v1/auth/me'):
          return ok(profileJson);
        case ('GET', path):
          return ok({
            'days': [
              {'id': 'day-1', 'day': date, 'seats_available': selected ? 0 : 1},
            ],
            'booking': selected
                ? {
                    'day_id': 'day-1',
                    'day': date,
                    'status': published ? 'confirmed' : 'day_selected',
                    'starts_at': published ? '${date}T09:00:00Z' : null,
                    'ends_at': published ? '${date}T09:20:00Z' : null,
                  }
                : null,
          });
        case ('PUT', path):
          expect(jsonDecode(request.body!), {'day_id': 'day-1'});
          selected = true;
          return ok({'status': 'day_selected'});
        default:
          fail(
            'Unexpected interview call ${request.method} ${request.uri.path}',
          );
      }
    });
    final session = StudentSession(
      api: CampusApi(transport: transport),
      store: MemoryTokenStore()..token = 'interview-token',
    );
    await session.restore();
    await tester.pumpWidget(
      StudentSessionScope(
        session: session,
        child: MaterialApp(home: StudentInterviewScreen(application)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(date));
    await tester.pumpAndSettle();
    expect(find.text('Day selected · $date UTC'), findsOneWidget);
    expect(find.text('Confirmed interview'), findsNothing);

    published = true;
    await tester.tap(find.byTooltip('Refresh interviews'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed interview'), findsOneWidget);
    expect(find.text('$date 09:00 UTC'), findsOneWidget);
    expect(find.text('Withdraw day selection'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
