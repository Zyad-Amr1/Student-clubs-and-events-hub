import 'package:campusconnect/core/config/api_config.dart';
import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/core/storage/token_store.dart';
import 'package:campusconnect/features/auth/data/auth_repository.dart';
import 'package:campusconnect/features/auth/models/student_profile.dart';
import 'package:campusconnect/features/clubs/data/clubs_repository.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.authRepository, required this.clubsRepository});

  factory AuthController.production() {
    final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
    final authRepository = AuthRepository(
      apiClient: apiClient,
      tokenStore: SecureTokenStore(),
    );
    return AuthController(
      authRepository: authRepository,
      clubsRepository: ClubsRepository(apiClient: apiClient),
    );
  }

  final AuthRepository authRepository;
  final ClubsRepository clubsRepository;

  bool _initialized = false;
  bool _isBusy = false;
  String? _sessionToken;
  String? _restoreError;
  String? _logoutWarning;
  StudentProfile? _profile;
  Future<void>? _initializeFuture;

  bool get isInitialized => _initialized;
  bool get isBusy => _isBusy;
  bool get isAuthenticated => _sessionToken != null && _profile != null;
  String? get sessionToken => _sessionToken;
  String? get restoreError => _restoreError;
  String? get logoutWarning => _logoutWarning;
  StudentProfile? get profile => _profile;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializeFuture ??= _restoreSession();
  }

  Future<void> _restoreSession() async {
    _isBusy = true;
    notifyListeners();
    try {
      final storedToken = await authRepository.readStoredToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        _sessionToken = storedToken;
        try {
          _profile = await authRepository.currentUser(storedToken);
        } on ApiException catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            await authRepository.clearStoredToken();
            _sessionToken = null;
          } else {
            _restoreError = error.message;
          }
        } catch (_) {
          _restoreError = 'Could not verify your saved session. Check your connection and sign in again.';
        }
      }
    } catch (_) {
      _restoreError =
          'Could not read your saved session. Please sign in again.';
    } finally {
      _initialized = true;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String universityId,
    required String password,
    required String confirmPassword,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      await authRepository.register(
        fullName: fullName,
        email: email,
        universityId: universityId,
        password: password,
        confirmPassword: confirmPassword,
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _isBusy = true;
    _restoreError = null;
    notifyListeners();
    try {
      final session = await authRepository.login(
        email: email,
        password: password,
      );
      _sessionToken = session.accessToken;
      _profile = session.profile;
      _logoutWarning = null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    final token = _sessionToken;
    if (token == null) return;
    _isBusy = true;
    notifyListeners();
    try {
      _profile = await authRepository.currentUser(token);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await authRepository.clearStoredToken();
        _sessionToken = null;
        _profile = null;
      }
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isBusy = true;
    _logoutWarning = null;
    notifyListeners();
    try {
      await authRepository.logout(_sessionToken);
    } on ApiException {
      _logoutWarning = 'Signed out on this device, but the server could not confirm token revocation.';
    } catch (_) {
      _logoutWarning = 'The saved session could not be cleared from secure storage. Please restart the app and sign in again.';
    } finally {
      _sessionToken = null;
      _profile = null;
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    authRepository.apiClient.close();
    super.dispose();
  }
}
