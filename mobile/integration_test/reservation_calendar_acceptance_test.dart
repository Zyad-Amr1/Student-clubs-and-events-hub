import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/student_home.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:campusconnect/features/events/presentation/my_events_screen.dart';
import 'package:campusconnect/features/events/presentation/student_event_details_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/acceptance_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'two real students: one seat, waitlist, FIFO promotion and calendar refresh',
    (tester) async {
      final api = CampusApi();
      final fixture = AcceptanceFixture(api);
      final affairs = await fixture.affairsToken();
      final creator = await fixture.student('event-creator');
      final studentA = await fixture.student('event-a');
      final studentB = await fixture.student('event-b');
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final club = await fixture.approveClub(
        studentToken: creator.token,
        affairsToken: affairs,
        name: 'Acceptance Reservations $suffix',
      );
      final event = await fixture.publishEvent(
        clubId: club.id,
        creatorToken: creator.token,
        affairsToken: affairs,
        title: 'Acceptance One Seat $suffix',
      );
      final a = await api.reserveEvent(studentA.token, event.id);
      final b = await api.reserveEvent(studentB.token, event.id);
      expect(a.status, ReservationStatus.confirmed);
      expect(b.status, ReservationStatus.waitlisted);
      expect(b.waitlistPosition, 1);

      const store = AndroidKeystoreTokenStore();
      await store.clear();
      await store.write(studentB.token);
      await store.writePortal('student');
      await tester.pumpWidget(CampusConnectApp(api: api));
      await tester.pumpAndSettle();
      expect(find.byType(StudentHome), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-calendar')));
      await tester.pumpAndSettle();
      expect(find.byType(MyEventsScreen), findsOneWidget);
      expect(find.text(event.title), findsOneWidget);
      expect(find.textContaining('Waitlisted'), findsOneWidget);

      await api.cancelReservation(studentA.token, event.id);
      await tester.tap(find.byTooltip('Refresh calendar'));
      await tester.pumpAndSettle();
      expect(find.text(event.title), findsOneWidget);
      expect(find.textContaining('Confirmed'), findsOneWidget);
      expect(find.textContaining('Waitlisted'), findsNothing);

      await tester.tap(find.text(event.title));
      await tester.pumpAndSettle();
      expect(find.byType(StudentEventDetailsScreen), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Cancel reservation'), findsOneWidget);

      final aAfter = (await api.myReservations(studentA.token))
          .singleWhere((item) => item.event.id == event.id);
      final bAfter = (await api.myReservations(studentB.token))
          .singleWhere((item) => item.event.id == event.id);
      expect(aAfter.status, ReservationStatus.cancelled);
      expect(bAfter.status, ReservationStatus.confirmed);
      expect(bAfter.waitlistPosition, isNull);
    },
  );
}
