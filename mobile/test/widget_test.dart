import 'package:campusconnect/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'welcome screen identifies CampusConnect and states integration status',
    (tester) async {
      await tester.pumpWidget(const CampusConnectApp());

      expect(find.text('CampusConnect'), findsOneWidget);
      expect(find.text('Your campus community starts here.'), findsOneWidget);
      expect(find.text('Live club data is not connected yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('open-auth')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('open-clubs')), findsOneWidget);
    },
  );

  testWidgets('authentication navigation opens an honest placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const CampusConnectApp());
    await tester.tap(find.byKey(const ValueKey<String>('open-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Your campus community starts here.'), findsNothing);
    expect(
      find.text(
        'Sign-in and registration will be added in the next milestone.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('club discovery navigation does not show fabricated data', (
    tester,
  ) async {
    await tester.pumpWidget(const CampusConnectApp());
    await tester.tap(find.byKey(const ValueKey<String>('open-clubs')));
    await tester.pumpAndSettle();

    expect(find.text('Your campus community starts here.'), findsNothing);
    expect(
      find.text('Club listings will appear here after API integration.'),
      findsOneWidget,
    );
    expect(find.text('Robotics Club'), findsNothing);
  });
}
