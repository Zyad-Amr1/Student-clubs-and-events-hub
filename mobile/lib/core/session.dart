import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

/// On Android, token bytes are encrypted by Android Keystore before persistence.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class AndroidKeystoreTokenStore implements TokenStore {
  const AndroidKeystoreTokenStore();

  static const MethodChannel _channel = MethodChannel(
    'campusconnect/secure_token',
  );

  @override
  Future<String?> read() => _channel.invokeMethod<String>('read');

  @override
  Future<void> write(String token) async {
    await _channel.invokeMethod<void>('write', {'token': token});
  }

  @override
  Future<void> clear() async {
    await _channel.invokeMethod<void>('delete');
  }
}

class StudentSession extends ChangeNotifier {
  StudentSession({required this.api, required this.store});

  final CampusApi api;
  final TokenStore store;

  String? _token;
  StudentProfile? _profile;
  bool _ready = false;
  bool _busy = false;
  String? _restoreError;

  bool get ready => _ready;
  bool get busy => _busy;
  bool get signedIn => _token != null && _profile != null;
  StudentProfile? get profile => _profile;
  String? get restoreError => _restoreError;

  Future<void> restore() async {
    _ready = false;
    _restoreError = null;
    notifyListeners();
    try {
      final saved = await store.read();
      if (saved != null && saved.isNotEmpty) {
        try {
          final user = await api.profile(saved);
          if (user.accountType == 'student') {
            _token = saved;
            _profile = user;
          } else {
            await store.clear();
          }
        } on ApiFailure catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            await store.clear();
          } else {
            _restoreError = error.message;
          }
        }
      }
    } catch (_) {
      _restoreError = 'Unable to access secure session storage.';
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _busy = true;
    notifyListeners();
    String? token;
    try {
      token = await api.login(email.trim(), password);
      final user = await api.profile(token);
      if (user.accountType != 'student') {
        try {
          await api.logout(token);
        } catch (_) {
          // Local access is denied even if remote revocation is unavailable.
        }
        throw const ApiFailure('This app is for Student accounts only.', statusCode: 403);
      }
      await store.write(token);
      _token = token;
      _profile = user;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> registerAndSignIn({
    required String fullName,
    required String email,
    required String universityId,
    required String password,
    required String confirmPassword,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await api.register(
        fullName: fullName.trim(),
        email: email.trim(),
        universityId: universityId.trim(),
        password: password,
        confirmPassword: confirmPassword,
      );
      // Registration returns a Student, NOT a JWT.
      await signIn(email, password);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<T> authenticated<T>(Future<T> Function(String token) call) async {
    final token = _token;
    if (token == null) {
      throw const ApiFailure('Please sign in again.', statusCode: 401);
    }
    try {
      return await call(token);
    } on ApiFailure catch (error) {
      if (error.statusCode == 401) {
        await _dropLocalSession();
      }
      rethrow;
    }
  }

  Future<void> _dropLocalSession() async {
    _token = null;
    _profile = null;
    try {
      await store.clear();
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final previousToken = _token;
    // Always remove local credentials, even if the server is unavailable.
    await _dropLocalSession();
    if (previousToken != null) {
      try {
        await api.logout(previousToken);
      } on ApiFailure {
        // Locally signed out; remote revocation may require retrying server-side.
      }
    }
  }
}
