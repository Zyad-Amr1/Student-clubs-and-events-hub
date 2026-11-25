import 'dart:convert';

import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:campusconnect/features/clubs/presentation/interview_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client_test.dart';

Future<StudentSession> launch(
  WidgetTester tester,
  Widget screen,
  FakeApiTransport transport,
) async {
  final session = StudentSession(
    api: CampusApi(transport: transport),
    store: MemoryTokenStore()..token = 'lifecycle-token',
  );
  await session.restore();
  await tester.pumpWidget(
    StudentSessionScope(
      session: session,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets(
    'calendar notification opens current cancellation and reselection state',
    (tester) async {
      const message =
          'Robotics Club cancelled your interview selection: Campus closure';
      final transport = FakeApiTransport((call) {
        switch ((call.method, call.uri.path)) {
          case ('GET', '/api/v1/auth/me'):
            return ok(profileJson);
          case ('GET', '/api/v1/me/interview-appointments'):
            return ok({
              'appointments': [
                {
                  'application_id': 'app-1',
                  'club_name': 'Robotics Club',
                  'status': 'cancelled',
                  'day': '2031-02-02',
                  'starts_at': null,
                  'ends_at': null,
                  'cancellation_reason': 'Campus closure',
                },
              ],
            });
          case ('GET', '/api/v1/me/interview-notices'):
            return ok({
              'notices': [
                {
                  'application_id': 'app-1',
                  'club_name': 'Robotics Club',
                  'message': message,
                  'created_at': '2031-02-01T10:00:00Z',
                },
              ],
            });
          case ('GET', '/api/v1/me/applications/app-1/interview'):
            return ok({
              'days': [],
              'booking': {
                'status': 'cancelled',
                'day': '2031-02-02',
                'day_id': 'old',
                'cancellation_reason': 'Campus closure',
              },
            });
          default:
            fail('Unexpected call ${call.uri}');
        }
      });
      final session = await launch(
        tester,
        const InterviewAppointmentsScreen(),
        transport,
      );
      expect(find.textContaining('Campus closure'), findsOneWidget);
      await tester.tap(find.text('Interview notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(message));
      await tester.pumpAndSettle();
      expect(find.text('No Available Days'), findsOneWidget);
      expect(find.text('Campus closure'), findsOneWidget);
      expect(find.text('Confirmed interview'), findsNothing);
      expect(find.text('Withdraw day selection'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  testWidgets('expired day prompts reselection and never displays No-show', (
    tester,
  ) async {
    const path = '/api/v1/me/applications/expired-app/interview';
    var selected = false;
    final transport = FakeApiTransport((call) {
      switch ((call.method, call.uri.path)) {
        case ('GET', '/api/v1/auth/me'):
          return ok(profileJson);
        case ('GET', path):
          return ok({
            'days': [
              {'id': 'new-day', 'day': '2031-02-03', 'seats_available': 1},
            ],
            'booking': selected
                ? {
                    'status': 'unscheduled',
                    'day': '2031-02-03',
                    'day_id': 'new-day',
                  }
                : {
                    'status': 'expired',
                    'day': '2031-02-02',
                    'day_id': 'old-day',
                  },
          });
        case ('PUT', path):
          expect(jsonDecode(call.body!), {'day_id': 'new-day'});
          selected = true;
          return ok({'status': 'unscheduled'});
        default:
          fail('Unexpected call ${call.uri}');
      }
    });
    final session = await launch(
      tester,
      const StudentInterviewScreen.forApplication(
        'expired-app',
        'Robotics Club',
      ),
      transport,
    );
    expect(
      find.textContaining('expired without an appointment'),
      findsOneWidget,
    );
    await tester.tap(find.text('2031-02-03'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment status · Unscheduled'), findsOneWidget);
    expect(find.textContaining('No-show'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets(
    'admin previews cancellation, supplies a reason and records finished attendance',
    (tester) async {
      const days = '/api/v1/club-admin/clubs/$clubId/interview-days';
      const day = '$days/day-1';
      var cancelled = false;
      var attendance = 'confirmed';
      final transport = FakeApiTransport((call) {
        switch ((call.method, call.uri.path)) {
          case ('GET', '/api/v1/auth/me'):
            return ok(profileJson);
          case ('GET', days):
            return ok({
              'days': [
                {
                  'id': 'day-1',
                  'day': '2031-02-02',
                  'selected': 2,
                  'capacity': 2,
                  'duration_minutes': 20,
                  'periods': [],
                },
              ],
            });
          case ('GET', '$day/schedule'):
            return ok({
              'periods': [],
              'cancellations': [],
              'slots': [
                {
                  'selection_id': 'first',
                  'applicant_name': 'First Student',
                  'status': cancelled ? 'cancelled' : 'confirmed',
                },
                {
                  'selection_id': 'finished',
                  'applicant_name': 'Finished Student',
                  'status': attendance,
                  'starts_at': '2020-02-02T09:00:00Z',
                  'ends_at': '2020-02-02T09:20:00Z',
                },
              ],
            });
          case ('POST', '$day/cancellation-preview'):
            expect(jsonDecode(call.body!), {
              'scope': 'appointment',
              'selection_id': 'first',
            });
            return ok({
              'preview_token': 'snapshot-token',
              'affected': [
                {'applicant_name': 'First Student', 'status': 'confirmed'},
              ],
            });
          case ('POST', '$day/cancel'):
            expect(jsonDecode(call.body!), {
              'target': {'scope': 'appointment', 'selection_id': 'first'},
              'preview_token': 'snapshot-token',
              'reason': 'Campus closure',
            });
            cancelled = true;
            return ok({'cancelled_count': 1});
          case ('PUT', '$day/appointments/finished/attendance'):
            expect(jsonDecode(call.body!), {'status': 'attended'});
            attendance = 'attended';
            return const ApiReply(204, '');
          default:
            fail('Unexpected call ${call.uri}');
        }
      });
      final session = await launch(
        tester,
        const AdminInterviewDaysScreen(
          ManagedClub(id: clubId, name: 'Robotics Club'),
        ),
        transport,
      );
      await tester.tap(find.text('Generate schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel appointment').first);
      await tester.pumpAndSettle();
      expect(find.text('1 affected students'), findsOneWidget);
      await tester.tap(find.text('Confirm cancellation'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a reason the affected students can see.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Campus closure');
      await tester.tap(find.text('Confirm cancellation'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);

      final record = find.text('Record Attended');
      await tester.ensureVisible(record);
      await tester.pumpAndSettle();
      await tester.tap(record);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record attendance'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Attended'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
