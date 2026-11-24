import 'dart:convert';

import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/core/storage/token_store.dart';
import 'package:campusconnect/features/auth/data/auth_repository.dart';
import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:campusconnect/features/clubs/data/clubs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'restores a saved session only after the backend confirms /me',
    () async {
      final tokenStore = MemoryTokenStore()..value = 'saved-jwt';
      final controller = createController(
        tokenStore,
        MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/me');
          expect(request.headers['authorization'], 'Bearer saved-jwt');
          return http.Response(jsonEncode(profileJson), 200);
        }),
      );

      await controller.initialize();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile?.email, 'student@example.edu');
      expect(controller.sessionToken, 'saved-jwt');
      controller.dispose();
    },
  );

  test('clears a saved token when the backend rejects its session', () async {
    final tokenStore = MemoryTokenStore()..value = 'revoked-jwt';
    final controller = createController(
      tokenStore,
      MockClient(
        (_) async =>
            http.Response(jsonEncode({'detail': 'Invalid token'}), 401),
      ),
    );

    await controller.initialize();

    expect(controller.isAuthenticated, isFalse);
    expect(tokenStore.value, isNull);
    controller.dispose();
  });
}

AuthController createController(
  MemoryTokenStore tokenStore,
  http.Client client,
) {
  final api = ApiClient(baseUrl: 'https://campus.example.test', client: client);
  return AuthController(
    authRepository: AuthRepository(apiClient: api, tokenStore: tokenStore),
    clubsRepository: ClubsRepository(apiClient: api),
  );
}

const profileJson = <String, Object>{
  'id': 'a1c973fd-9bc7-4f81-95e2-0392408e94b6',
  'full_name': 'Student Name',
  'email': 'student@example.edu',
  'university_id': 'U-103',
  'account_type': 'student',
  'is_active': true,
  'created_at': '2026-11-20T10:30:00Z',
};

class MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String accessToken) async => value = accessToken;
}
