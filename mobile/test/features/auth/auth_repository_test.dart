import 'dart:convert';

import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/core/storage/token_store.dart';
import 'package:campusconnect/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'registration posts only account fields and never stores a token',
    () async {
      final tokenStore = MemoryTokenStore();
      late Map<String, dynamic> sentBody;
      final repository = AuthRepository(
        apiClient: ApiClient(
          baseUrl: 'https://campus.example.test',
          client: MockClient((request) async {
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode(profileJson), 201);
          }),
        ),
        tokenStore: tokenStore,
      );

      await repository.register(
        fullName: 'Rana Ali',
        email: 'rana@example.edu',
        universityId: 'U-103',
        password: 'correct-horse',
        confirmPassword: 'correct-horse',
      );

      expect(sentBody.keys.toSet(), {
        'full_name',
        'email',
        'university_id',
        'password',
        'confirm_password',
      });
      expect(tokenStore.value, isNull);
    },
  );

  test(
    'login stores the returned JWT and loads the profile from auth/me',
    () async {
      final tokenStore = MemoryTokenStore();
      final repository = AuthRepository(
        apiClient: ApiClient(
          baseUrl: 'https://campus.example.test',
          client: MockClient((request) async {
            if (request.url.path == '/api/v1/auth/login') {
              return http.Response(
                jsonEncode({
                  'access_token': 'signed-jwt',
                  'token_type': 'bearer',
                  'expires_in': 1800,
                }),
                200,
              );
            }
            expect(request.url.path, '/api/v1/auth/me');
            expect(request.headers['authorization'], 'Bearer signed-jwt');
            return http.Response(jsonEncode(profileJson), 200);
          }),
        ),
        tokenStore: tokenStore,
      );

      final session = await repository.login(
        email: 'rana@example.edu',
        password: 'correct-horse',
      );

      expect(session.accessToken, 'signed-jwt');
      expect(session.profile.email, 'rana@example.edu');
      expect(tokenStore.value, 'signed-jwt');
    },
  );

  test(
    'logout clears local token storage even when server revocation fails',
    () async {
      final tokenStore = MemoryTokenStore()..value = 'expired-jwt';
      final repository = AuthRepository(
        apiClient: ApiClient(
          baseUrl: 'https://campus.example.test',
          client: MockClient((_) async => http.Response('', 401)),
        ),
        tokenStore: tokenStore,
      );

      await expectLater(
        repository.logout('expired-jwt'),
        throwsA(isA<ApiException>()),
      );
      expect(tokenStore.value, isNull);
    },
  );
}

const profileJson = <String, Object>{
  'id': 'a1c973fd-9bc7-4f81-95e2-0392408e94b6',
  'full_name': 'Rana Ali',
  'email': 'rana@example.edu',
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
