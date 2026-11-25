import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client_test.dart';
import 'event_workflow_test.dart' show eventId;

void main() {
  testWidgets(
    'club RSVP appears on calendar and can be cancelled from details',
    (tester) async {
      final event = {
        'id': eventId,
        'club_id': clubId,
        'title': 'Robotics Workshop',
        'description': 'Build a robot',
        'venue': 'Engineering Hall',
        'starts_at': '2099-11-26T10:00:00Z',
        'ends_at': null,
        'seat_capacity': 1,
      };
      var reserved = false;
      var promoted = false;
      final booking = {
        'event_id': eventId,
        'status': 'waitlisted',
        'waitlist_position': 2,
        'event': event,
      };
      final transport = FakeApiTransport((call) {
        expect(call.headers['Authorization'], 'Bearer student-test-token');
        switch ((call.method, call.uri.path)) {
          case ('GET', '/api/v1/auth/me'):
            return ok(profileJson);
          case ('GET', '/api/v1/clubs'):
            return ok({
              'clubs': [clubJson],
              'page': 1,
              'page_size': 20,
              'total': 1,
            });
          case ('GET', '/api/v1/clubs/$clubId'):
            return ok({
              'club': clubJson,
              'events': [event],
              'total': 1,
            });
          case ('GET', '/api/v1/me/reservations'):
            return ok({
              'reservations': [
                if (reserved)
                  if (promoted)
                    {
                      ...booking,
                      'status': 'confirmed',
                      'waitlist_position': null,
                    }
                  else
                    booking,
              ],
            });
          case ('POST', '/api/v1/events/$eventId/reservations'):
            expect(call.body, isNull);
            reserved = true;
            return ok(booking, 201);
          case ('DELETE', '/api/v1/events/$eventId/reservations'):
            expect(call.body, isNull);
            reserved = false;
            return const ApiReply(204, '');
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
      await tester.tap(find.byKey(const ValueKey('club-$clubId')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('event-$eventId')));
      await tester.tap(find.byKey(const ValueKey('event-$eventId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reserve a place'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Waitlisted · position 2'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-calendar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Waitlisted · position 2'), findsOneWidget);
      final calendarContext = tester.element(find.text('My Events Calendar'));
      final dateLabel = MaterialLocalizations.of(
        calendarContext,
      ).formatFullDate(DateTime.parse(event['starts_at'] as String).toLocal());
      expect(find.text(dateLabel), findsOneWidget);

      promoted = true;
      await tester.tap(find.byTooltip('Refresh calendar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmed'), findsOneWidget);
      await tester.tap(find.text('Robotics Workshop'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Build a robot'), findsOneWidget);
      await tester.tap(find.text('Cancel reservation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel reservation').last);
      await tester.pumpAndSettle();
      expect(find.text('Reserve a place'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('You have no event reservations yet.'), findsOneWidget);
    },
  );
}
