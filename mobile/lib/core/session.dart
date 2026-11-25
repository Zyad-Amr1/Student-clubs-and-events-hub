import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'portal_role.dart';

/// On Android, token bytes are encrypted by Android Keystore before persistence.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();


}

/// Optional preference interface: old Student token stores remain compatible.
abstract class PortalPreferenceStore {
  Future<String?> readPortal();
  Future<void> writePortal(String portal);
}

class AndroidKeystoreTokenStore implements TokenStore, PortalPreferenceStore {
  const AndroidKeystoreTokenStore();

  static const MethodChannel _channel = MethodChannel(
    'campusconnect/secure_token',
  );

  @override
  Future<String?> readPortal() => _channel.invokeMethod<String>('readPortal');

  @override
  Future<void> writePortal(String portal) async {
    await _channel.invokeMethod<void>('writePortal', {'portal': portal});
  }

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
  PortalRole _portal = PortalRole.student;
  List<ManagedClub> _managedClubs = const [];

  bool get ready => _ready;
  bool get busy => _busy;
  bool get signedIn => _token != null && _profile != null;
  StudentProfile? get profile => _profile;
  PortalRole get portal => _portal;
  List<ManagedClub> get managedClubs => List.unmodifiable(_managedClubs);
  String? get restoreError => _restoreError;

  Future<List<ManagedClub>> _verifyPortal(
    String token,
    StudentProfile user,
    PortalRole portal,
  ) async {
    switch (portal) {
      case PortalRole.student:
        if (user.accountType != 'student') {
          throw const ApiFailure(
            'This portal requires a Student account.',
            statusCode: 403,
          );
        }
        return const [];
      case PortalRole.clubAdmin:
        if (user.accountType != 'student') {
          throw const ApiFailure(
            'Club administration requires a Student account.',
            statusCode: 403,
          );
        }
        final assigned = await api.managedClubs(token);
        if (assigned.isEmpty) {
          throw const ApiFailure(
            'No club administrator assignment found.',
            statusCode: 403,
          );
        }
        return assigned;
      case PortalRole.studentAffairs:
        if (user.accountType != 'student_affairs') {
          throw const ApiFailure(
            'This portal requires a Student Affairs account.',
            statusCode: 403,
          );
        }
        await api.verifyStudentAffairs(token);
        return const [];
    }
  }

  Future<void> restore() async {
    _ready = false;
    _restoreError = null;
    notifyListeners();
    try {
      final saved = await store.read();
      if (saved != null && saved.isNotEmpty) {
        try {
          final user = await api.profile(saved);
          final savedChoice = portalFromStorage(
            store is PortalPreferenceStore
                ? await (store as PortalPreferenceStore).readPortal()
                : null,
          );
          final choice =
              savedChoice ??
              (user.accountType == 'student_affairs'
                  ? PortalRole.studentAffairs
                  : PortalRole.student);
          final clubs = await _verifyPortal(saved, user, choice);
          _token = saved;
          _profile = user;
          _portal = choice;
          _managedClubs = clubs;
        } on ApiFailure catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            await _dropLocalSession();
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

  Future<void> signIn(
    String email,
    String password, {
    PortalRole portal = PortalRole.student,
  }) async {
    _busy = true;
    notifyListeners();
    String? token;
    try {
      token = await api.login(email.trim(), password);
      final user = await api.profile(token);
      final clubs = await _verifyPortal(token, user, portal);
      await store.write(token);
      if (store is PortalPreferenceStore) {
        await (store as PortalPreferenceStore).writePortal(portal.name);
      }
      _token = token;
      _profile = user;
      _portal = portal;
      _managedClubs = clubs;
    } catch (_) {
      try {
        await store.clear();
      } catch (_) {
        // Never keep an unauthorized local session even if storage is unavailable.
      }
      if (token != null) {
        try {
          await api.logout(token);
        } catch (_) {
          // Local authorization remains denied; remote revocation best effort.
        }
      }
      rethrow;
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
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _dropLocalSession();
      }
      rethrow;
    }
  }

  Future<void> refreshPortalAccess() async {
    await authenticated((token) async {
      final user = await api.profile(token);
      final clubs = await _verifyPortal(token, user, _portal);
      _profile = user;
      _managedClubs = clubs;
      notifyListeners();
    });
  }

  Future<void> _dropLocalSession() async {
    _token = null;
    _profile = null;
    _portal = PortalRole.student;
    _managedClubs = const [];
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
