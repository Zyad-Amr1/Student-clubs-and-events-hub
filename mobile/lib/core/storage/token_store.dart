import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();

  Future<void> write(String accessToken);

  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'campusconnect_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _accessTokenKey);

  @override
  Future<void> write(String accessToken) =>
      _storage.write(key: _accessTokenKey, value: accessToken);

  @override
  Future<void> delete() => _storage.delete(key: _accessTokenKey);
}
