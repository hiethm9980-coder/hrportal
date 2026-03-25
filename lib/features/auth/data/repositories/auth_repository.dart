// ⚠️ API CONTRACT v1.0.0 — Endpoints match §3 exactly.

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/base_response.dart';
import '../../../../core/network/session_manager.dart';
import '../../../profile/data/models/employee_profile_model.dart';
import '../models/auth_models.dart';

/// Repository for authentication operations.
///
/// Endpoints:
///   POST /auth/login     → [login]
///   POST /auth/logout    → [logout]
///   POST /auth/logout-all → [logoutAll]
///   GET  /auth/me        → [getCurrentUser]
class AuthRepository {
  final ApiClient _client;
  final SessionManager _sessionManager;

  AuthRepository({
    required ApiClient client,
    required SessionManager sessionManager,
  })  : _client = client,
        _sessionManager = sessionManager;

  /// Authenticate with username/password. Returns token + profile.
  ///
  /// On success, persists the token and employee context in secure storage.
  ///
  /// Throws:
  ///   - [ValidationException] if fields are invalid
  ///   - [AuthRequiredException] if credentials are wrong
  ///   - [RateLimitedException] after 10 failed attempts/minute
  Future<LoginData> login({
    required String username,
    required String password,
  }) async {
    print('Login request: ${ApiConstants.login}');
    final response = await _client.post<LoginData>(
      ApiConstants.login,
      fromJson: (json) => LoginData.fromJson(json as Map<String, dynamic>),
      data: {
        'username': username,
        'password': password,
      },
    );

    final loginData = response.data!;

    // Persist session
    await _sessionManager.onLoginSuccess(
      token: loginData.token,
      employeeId: loginData.employee.id,
      companyId: loginData.employee.company?.id ?? 0,
    );

    // Persist manager flag for session restore
    await _sessionManager.storage.saveIsManager(loginData.employee.isManager);

    return loginData;
  }

  /// Revoke the current token (single device logout).
  ///
  /// Clears local secure storage.
  Future<void> logout() async {
    try {
      await _client.post<void>(ApiConstants.logout);
    } finally {
      // Always clear local state, even if the API call fails.
      await _sessionManager.onLogout();
    }
  }

  /// Revoke ALL tokens for this user (all devices).
  ///
  /// Returns the number of tokens revoked.
  Future<int> logoutAll() async {
    final response = await _client.post<LogoutAllData>(
      ApiConstants.logoutAll,
      fromJson: (json) =>
          LogoutAllData.fromJson(json as Map<String, dynamic>),
    );

    await _sessionManager.onLogout();
    return response.data!.revokedTokens;
  }

  /// Get the currently authenticated employee's profile.
  ///
  /// Useful for validating a restored session on app startup.
  Future<EmployeeProfile> getCurrentUser() async {
    final response = await _client.get<EmployeeProfile>(
      ApiConstants.me,
      fromJson: (json) =>
          EmployeeProfile.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
