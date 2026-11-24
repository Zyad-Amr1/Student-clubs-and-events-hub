import 'dart:convert';

import 'package:campusconnect/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends filters and bearer token to the versioned API', () async {
    late http.Request captured;
    final api = ApiClient(
      baseUrl: 'https://campus.example.test/',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'clubs': <Object>[],
            'page': 1,
            'page_size': 100,
            'total': 0,
          }),
          200,
        );
      }),
    );

    await api.getJson(
      '/clubs',
      accessToken: 'jwt-value',
      queryParameters: {'search': 'Robotics & AI', 'category': 'Technology'},
    );

    expect(captured.url.path, '/api/v1/clubs');
    expect(captured.url.queryParameters, {
      'search': 'Robotics & AI',
      'category': 'Technology',
    });
    expect(captured.headers['authorization'], 'Bearer jwt-value');
  });

  test(
    'turns backend validation details into a readable API exception',
    () async {
      final api = ApiClient(
        baseUrl: 'https://campus.example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'detail': [
                {
                  'loc': ['body', 'email'],
                  'msg': 'value is not a valid email address',
                },
              ],
            }),
            422,
          ),
        ),
      );

      await expectLater(
        api.postJson('/auth/register', body: const {}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.message, 'message', contains('email')),
        ),
      );
    },
  );

  test('accepts the backend no-content logout response', () async {
    final api = ApiClient(
      baseUrl: 'https://campus.example.test',
      client: MockClient((_) async => http.Response('', 204)),
    );

    await expectLater(
      api.postNoContent('/auth/logout', accessToken: 'jwt-value'),
      completes,
    );
  });
}
