import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must be an HTTP(S) URL.');
    }
  }

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
    Map<String, String> queryParameters = const {},
  }) async {
    final result = await _request(
      'GET',
      path,
      accessToken: accessToken,
      queryParameters: queryParameters,
    );
    if (result is Map<String, dynamic>) return result;
    throw const ApiException('The server returned an unexpected response.');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    String? accessToken,
  }) async {
    final result = await _request(
      'POST',
      path,
      body: body,
      accessToken: accessToken,
    );
    if (result is Map<String, dynamic>) return result;
    throw const ApiException('The server returned an unexpected response.');
  }

  Future<void> postNoContent(String path, {String? accessToken}) async {
    await _request('POST', path, accessToken: accessToken);
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
    Map<String, String> queryParameters = const {},
  }) async {
    final query = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) query[entry.key] = value;
    }
    final uri = Uri.parse('$_baseUrl/api/v1$path')
        .replace(queryParameters: query.isEmpty ? null : query);
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }

    try {
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers).timeout(timeout),
        'POST' =>
          await _client
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(timeout),
        _ => throw ArgumentError.value(
          method,
          'method',
          'Unsupported HTTP method.',
        ),
      };

      final decoded = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _errorMessage(decoded),
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Could not connect to CampusConnect. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not connect to CampusConnect. Check your connection and try again.',
      );
    } on FormatException {
      throw const ApiException('The server returned an unreadable response.');
    }
  }

  Object? _decodeBody(http.Response response) {
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  String _errorMessage(Object? body) {
    if (body is! Map<String, dynamic>) {
      return 'The request failed. Please try again.';
    }
    final detail = body['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List) {
      final messages = detail
          .map((item) {
            if (item is! Map<String, dynamic>) return item.toString();
            final location = item['loc'];
            final field = location is List && location.isNotEmpty
                ? location.last.toString()
                : '';
            final message = item['msg']?.toString() ?? 'Invalid value';
            return field.isEmpty ? message : '$field: $message';
          })
          .where((message) => message.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return 'The request failed. Please try again.';
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
