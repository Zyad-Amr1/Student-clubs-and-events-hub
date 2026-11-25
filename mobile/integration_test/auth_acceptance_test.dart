import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/student_home.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/core/session.dart';
import 'package:campusconnect/features/auth/presentation/role_home_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const affairsEmail = String.fromEnvironment('ACCEPTANCE_AFFAIRS_EMAIL');
const affairsPassword = String.fromEnvironment('ACCEPTANCE_AFFAIRS_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real backend registration, session restoration, roles and logout',
    (tester) async {
      expect(affairsEmail, isNotEmpty, reason: 'Set ACCEPTANCE_AFFAIRS_EMAIL.');
      expect(
        affairsPassword,
        isNotEmpty,
        reason: 'Set ACCEPTANCE_AFFAIRS_PASSWORD.',
      );
      final api = CampusApi();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'acceptance-$suffix@example.edu';
      final universityId = 'ACCEPT-$suffix';
      const password = 'Acceptance-Student#2026';
      final store = const AndroidKeystoreTokenStore();
      await store.clear();

      await tester.pumpWidget(CampusConnectApp(api: api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-auth')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('register-name')),
        'Acceptance Student',
      );
      await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
      await tester.enterText(
        find.byKey(const ValueKey('register-university-id')),
        universityId,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        password,
      );
      await tester.enterText(
        find.byKey(const ValueKey('register-confirm-password')),
        password,
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(StudentHome), findsOneWidget);
      final token = await store.read();
      expect(token, isNotNull);
      expect((await api.profile(token!)).accountType, 'student');

      await expectLater(
        api.register(
          fullName: 'Duplicate Student',
          email: email,
          universityId: universityId,
          password: password,
          confirmPassword: password,
        ),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      await expectLater(
        api.register(
          fullName: 'Duplicate Identifier',
          email: 'other-$suffix@example.edu',
          universityId: universityId,
          password: password,
          confirmPassword: password,
        ),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
      // Rebuilds the app in the same Android process and restores its saved token.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(CampusConnectApp(api: api));
      await tester.pumpAndSettle();
      expect(find.byType(StudentHome), findsOneWidget);
      expect(await store.read(), token);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('header-open-profile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-logout')));
      await tester.pumpAndSettle();
      expect(await store.read(), isNull);
      await expectLater(
        api.profile(token),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-auth')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-error')), findsOneWidget);
      expect(await store.read(), isNull);
      await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        password,
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(StudentHome), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('header-open-profile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-auth')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        affairsEmail,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        affairsPassword,
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(RoleHomeScreen), findsOneWidget);
      final affairsToken = await store.read();
      expect((await api.profile(affairsToken!)).accountType, 'student_affairs');
      await tester.tap(find.byKey(const ValueKey('role-logout')));
      await tester.pumpAndSettle();
      expect(await store.read(), isNull);
    },
  );
}
