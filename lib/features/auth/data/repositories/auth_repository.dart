// ⚠️ API CONTRACT v1.0.0 — Endpoints match §3 exactly.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_manager.dart';
import '../../../../core/utils/login_device_snapshot.dart';
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
    String? fcmToken,
  }) async {
    debugPrint('Login request: ${ApiConstants.login}');
    final data = <String, dynamic>{
      'username': username,
      'password': password,
    };
    if (fcmToken != null && fcmToken.isNotEmpty) {
      data['fcm_token'] = fcmToken;
    }
    try {
      final snapshotMap = await collectLoginDeviceSnapshot().timeout(
        const Duration(seconds: 6),
        onTimeout: () => {
          'error': 'device_info_timeout',
          'device_label': 'timeout',
          'schema': 'login_client_snapshot_v2',
        },
      );
      final fullJson = jsonEncode(snapshotMap);
      final maxLen = ApiConstants.loginDeviceNameServerMaxChars;

      String deviceNameStr = fullJson;
      if (deviceNameStr.length > maxLen) {
        deviceNameStr = jsonEncode(compactDeviceSnapshotMap(snapshotMap));
      }
      if (deviceNameStr.length > maxLen) {
        deviceNameStr = jsonEncode(minimalDeviceSnapshotMap(snapshotMap));
      }
      data['device_name'] = deviceNameStr;

      if (ApiConstants.loginSendFullDeviceSnapshotField &&
          fullJson.length > maxLen) {
        data[ApiConstants.loginDeviceSnapshotField] = fullJson;
      }
    } catch (e, st) {
      final err = <String, dynamic>{
        'error': 'device_info_failed',
        'message': e.toString(),
      };
      if (kDebugMode) err['stack'] = st.toString();
      data['device_name'] = jsonEncode(err);
    }
    final response = await _client.post<LoginData>(
      ApiConstants.login,
      fromJson: (json) => LoginData.fromJson(json as Map<String, dynamic>),
      data: data,
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

    // Persist approvals context — `/auth/me` may not return these on every
    // backend version, so we keep a local copy to survive session restore.
    await _sessionManager.storage.saveApprovalsFlagsJson(
      loginData.approvals != null
          ? jsonEncode(loginData.approvals!.toJson())
          : null,
    );
    await _sessionManager.storage.saveManagedCompaniesJson(
      loginData.managedCompanies.isEmpty
          ? null
          : jsonEncode(
              loginData.managedCompanies.map((e) => e.toJson()).toList(),
            ),
    );

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

  /// Change password. On success, the user should be logged out.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _client.post<void>(
      ApiConstants.changePassword,
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );
    return response.message;
  }

  /// Get the currently authenticated employee's profile, along with approval
  /// flags and managed companies.
  ///
  /// Useful for validating a restored session on app startup.
  Future<CurrentUserData> getCurrentUser() async {
    final response = await _client.get<CurrentUserData>(
      ApiConstants.me,
      fromJson: (json) =>
          CurrentUserData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
