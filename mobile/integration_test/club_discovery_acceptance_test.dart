import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/student_home.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:campusconnect/features/clubs/presentation/clubs_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/acceptance_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real club discovery filters, pages, resets and shows events', (
    tester,
  ) async {
    final api = CampusApi();
    final fixture = AcceptanceFixture(api);
    final affairs = await fixture.affairsToken();
    final creator = await fixture.student('club-creator');
    final viewer = await fixture.student('club-viewer');
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final prefix = 'Acceptance $suffix';
    final clubs = <ManagedClub>[];
    for (var i = 0; i < 21; i++) {
      clubs.add(
        await fixture.approveClub(
          studentToken: creator.token,
          affairsToken: affairs,
          name: '$prefix Science ${i.toString().padLeft(2, '0')}',
        ),
      );
    }
    final otherCategory = await fixture.approveClub(
      studentToken: creator.token,
      affairsToken: affairs,
      name: '$prefix Arts',
      category: 'Arts',
    );
    final archived = await fixture.approveClub(
      studentToken: creator.token,
      affairsToken: affairs,
      name: '$prefix Archived',
    );
    final preview = await api.archivePreview(affairs, archived.id);
    await api.archiveClub(
      affairs,
      archived.id,
      'Acceptance archive',
      preview['preview_token'] as String,
    );
    await api.saveClubRequest(creator.token, {
      'name': '$prefix Pending',
      'description': 'Not yet approved.',
      'category': 'Science',
    });
    final event = await fixture.publishEvent(
      clubId: clubs.first.id,
      creatorToken: creator.token,
      affairsToken: affairs,
      title: '$prefix Welcome Event',
    );

    final first = await api.clubs(
      viewer.token,
      search: prefix,
      category: 'Science',
    );
    final second = await api.clubs(
      viewer.token,
      page: 2,
      search: prefix,
      category: 'Science',
    );
    expect(first.total, 21);
    expect(first.clubs, hasLength(20));
    expect(second.clubs, hasLength(1));
    expect(
      first.clubs
          .map((club) => club.id)
          .toSet()
          .intersection(second.clubs.map((club) => club.id).toSet()),
      isEmpty,
    );
    final arts = await api.clubs(
      viewer.token,
      search: prefix,
      category: 'Arts',
    );
    expect(arts.clubs.single.id, otherCategory.id);
    final all = await api.clubs(viewer.token, search: prefix);
    expect(all.total, 22);
    expect(all.clubs.map((club) => club.id), isNot(contains(archived.id)));
    final detail = await api.clubDetails(viewer.token, clubs.first.id);
    expect(detail.events.map((item) => item.id), contains(event.id));

    const store = AndroidKeystoreTokenStore();
    await store.clear();
    await store.write(viewer.token);
    await store.writePortal('student');
    await tester.pumpWidget(CampusConnectApp(api: api));
    await tester.pumpAndSettle();
    expect(find.byType(StudentHome), findsOneWidget);
    expect(find.byType(ClubsScreen), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('club-search')), prefix);
    await tester.enterText(
      find.byKey(const ValueKey('club-category-filter')),
      'Science',
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('load-more-clubs')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('club-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('load-more-clubs')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('club-${clubs.last.id}')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('club-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(ValueKey('club-${clubs.last.id}')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('club-category-filter')),
      'Arts',
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(ValueKey('club-${otherCategory.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('load-more-clubs')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('club-category-filter')),
      'Science',
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byKey(ValueKey('club-${clubs.first.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('club-details')), findsOneWidget);
    expect(find.byKey(ValueKey('event-${event.id}')), findsOneWidget);
  });
}
