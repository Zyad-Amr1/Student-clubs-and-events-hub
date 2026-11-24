import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/core/storage/token_store.dart';
import 'package:campusconnect/features/auth/models/student_profile.dart';

class AuthenticatedSession {
  const AuthenticatedSession({
    required this.accessToken,
    required this.profile,
  });

  final String accessToken;
  final StudentProfile profile;
}

class AuthRepository {
  const AuthRepository({required this.apiClient, required this.tokenStore});

  final ApiClient apiClient;
  final TokenStore tokenStore;

  Future<StudentProfile> register({
    required String fullName,
    required String email,
    required String universityId,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await apiClient.postJson(
      '/auth/register',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'university_id': universityId.trim(),
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
    return StudentProfile.fromJson(response);
  }

  Future<AuthenticatedSession> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.postJson(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    final accessToken = response['access_token'];
    final tokenType = response['token_type'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        tokenType is! String ||
        tokenType.toLowerCase() != 'bearer') {
      throw const ApiException(
        'The server returned an invalid sign-in response.',
      );
    }

    await tokenStore.write(accessToken);
    try {
      final profile = await currentUser(accessToken);
      return AuthenticatedSession(accessToken: accessToken, profile: profile);
    } catch (_) {
      await tokenStore.delete();
      rethrow;
    }
  }

  Future<StudentProfile> currentUser(String accessToken) async {
    final response = await apiClient.getJson(
      '/auth/me',
      accessToken: accessToken,
    );
    return StudentProfile.fromJson(response);
  }

  Future<String?> readStoredToken() => tokenStore.read();

  Future<void> clearStoredToken() => tokenStore.delete();

  Future<void> logout(String? accessToken) async {
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await apiClient.postNoContent('/auth/logout', accessToken: accessToken);
      }
    } finally {
      await tokenStore.delete();
    }
  }
}
