import 'dart:async';

import '../storage/secure_token_storage.dart';

/// Callback signature for session expiry notification.
///
/// The UI layer registers a callback here. When a 401 TOKEN_EXPIRED
/// is received, this fires so the UI can navigate to login.
typedef SessionExpiredCallback = void Function(String message);

/// Manages user session lifecycle.
///
/// Responsibilities:
/// 1. Track whether user is authenticated
/// 2. Clear tokens on session expiry
/// 3. Notify UI layer to navigate to login screen
///
/// Usage (in app initialization):
/// ```dart
/// final sessionManager = SessionManager(storage: secureStorage);
/// sessionManager.onSessionExpired = (msg) {
///   navigatorKey.currentState?.pushReplacementNamed('/login');
///   showSnackBar(msg);
/// };
/// ```
class SessionManager {
  final SecureTokenStorage _storage;

  /// Expose storage for saving extra session data (e.g., isManager).
  SecureTokenStorage get storage => _storage;

  /// Set this callback from the UI layer to handle navigation on expiry.
  SessionExpiredCallback? onSessionExpired;

  /// Stream that emits `true` when logged in, `false` when logged out.
  Stream<bool> get authStateStream => _authStateController.stream;
  final _authStateController = StreamController<bool>.broadcast();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  SessionManager({required SecureTokenStorage storage}) : _storage = storage;

  /// Call after successful login.
  Future<void> onLoginSuccess({
    required String token,
    required int employeeId,
    required int companyId,
  }) async {
    await _storage.saveToken(token);
    await _storage.saveEmployeeId(employeeId);
    await _storage.saveCompanyId(companyId);
    _isAuthenticated = true;
    _authStateController.add(true);
  }

  /// Call on voluntary logout.
  Future<void> onLogout() async {
    await _storage.clearAll();
    _isAuthenticated = false;
    _authStateController.add(false);
  }

  /// Called by the Dio interceptor when a 401 TOKEN_EXPIRED is received.
  ///
  /// Clears storage and notifies the UI to navigate to login.
  Future<void> onTokenExpired() async {
    await _storage.clearAll();
    _isAuthenticated = false;
    _authStateController.add(false);
    onSessionExpired?.call('Your session has expired. Please sign in again.');
  }

  /// Check if user has a stored token on app startup.
  Future<bool> tryRestoreSession() async {
    final hasToken = await _storage.hasToken();
    _isAuthenticated = hasToken;
    _authStateController.add(hasToken);
    return hasToken;
  }

  /// Clean up resources.
  void dispose() {
    _authStateController.close();
  }
}
