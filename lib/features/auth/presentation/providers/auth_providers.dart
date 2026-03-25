import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pwa_install/pwa_install.dart';
import 'dart:async';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/auth_models.dart';
import '../../../profile/data/models/employee_profile_model.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../leave/presentation/providers/leave_providers.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart';
import '../../../requests/presentation/providers/request_providers.dart';
import '../../../manager_requests/presentation/providers/manager_request_providers.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Auth State
// ═══════════════════════════════════════════════════════════════════

/// Global auth state — tracks whether the user is logged in.
///
/// GoRouter listens to this to decide redirects.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final EmployeeProfile? employee;

  const AuthState({this.status = AuthStatus.unknown, this.employee});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get isUnknown => status == AuthStatus.unknown;

  /// Whether the user has manager/approval permissions.
  bool get isManager => employee?.canManageRequests ?? false;

  AuthState copyWith({AuthStatus? status, EmployeeProfile? employee}) {
    return AuthState(
      status: status ?? this.status,
      employee: employee ?? this.employee,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Auth Notifier
// ═══════════════════════════════════════════════════════════════════

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  late final StreamSubscription<bool> _authSub;

  AuthNotifier(this._ref) : super(const AuthState()) {
    // Keep AuthState in sync when SessionManager triggers auto-logout
    // (e.g., TOKEN_EXPIRED/TOKEN_INVALID in AuthInterceptor).
    _authSub = _ref.read(sessionManagerProvider).authStateStream.listen((
      isAuthenticated,
    ) {
      if (!isAuthenticated && state.isAuthenticated) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  /// Called once at app startup from SplashScreen.
  ///
  /// Checks for stored token → validates with GET /auth/me.
  Future<void> checkSession() async {
    final session = _ref.read(sessionManagerProvider);
    final hasToken = await session.tryRestoreSession();

    if (!hasToken) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Read stored manager flag (saved at login time).
    final storedIsManager = await session.storage.getIsManager();

    // Token exists — validate it with the server.
    try {
      final auth = _ref.read(authRepositoryProvider);
      var employee = await auth.getCurrentUser();

      // Always apply stored isManager flag if API /me doesn't return it.
      if (!employee.isManager && storedIsManager) {
        employee = employee.copyWith(isManager: true);
      }
      // If API returned it, update storage for next time.
      if (employee.isManager && !storedIsManager) {
        await session.storage.saveIsManager(true);
      }

      state = AuthState(status: AuthStatus.authenticated, employee: employee);
    } on TokenExpiredException {
      await session.onLogout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on TokenInvalidException {
      await session.onLogout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on ApiException {
      // Network error — assume authenticated (offline mode).
      state = AuthState(
        status: AuthStatus.authenticated,
        employee: storedIsManager
            ? const EmployeeProfile(
                id: 0,
                code: '',
                name: '',
                initials: '',
                employmentStatus: '',
                isManager: true,
              )
            : null,
      );
    }
  }

  /// Update the stored employee profile (e.g. after profile edit).
  void updateEmployee(EmployeeProfile employee) {
    state = state.copyWith(employee: employee);
  }

  /// Mark as logged out — GoRouter will redirect.
  ///
  /// Invalidates all user-specific providers so that a subsequent login
  /// starts with a clean slate (no stale data from the previous user).
  void onLogout() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(dashboardAttendanceProvider);
    _ref.invalidate(attendanceHistoryProvider);
    _ref.invalidate(leavesListProvider);
    _ref.invalidate(payslipListProvider);
    _ref.invalidate(requestsListProvider);
    _ref.invalidate(managerRequestsListProvider);
    _ref.invalidate(notificationsProvider);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Login Form Controller
// ═══════════════════════════════════════════════════════════════════

class LoginFormState {
  final String username;
  final String password;
  final bool isLoading;
  final bool obscurePassword;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;

  const LoginFormState({
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.obscurePassword = true,
    this.error,
    this.fieldErrors = const {},
  });

  bool get canSubmit =>
      username.isNotEmpty && password.isNotEmpty && !isLoading;

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors != null && errors.isNotEmpty ? errors.first : null;
  }

  LoginFormState copyWith({
    String? username,
    String? password,
    bool? isLoading,
    bool? obscurePassword,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool clearErrors = false,
  }) {
    return LoginFormState(
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
    );
  }
}

class LoginFormController extends StateNotifier<LoginFormState> {
  final Ref _ref;

  LoginFormController(this._ref) : super(const LoginFormState());

  void setUsername(String value) =>
      state = state.copyWith(username: value.trim(), clearErrors: true);

  void setPassword(String value) =>
      state = state.copyWith(password: value, clearErrors: true);

  void togglePasswordVisibility() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  /// Submit login form.
  ///
  /// On success, updates [authProvider] which triggers GoRouter redirect.
  Future<void> submit() async {
    if (PWAInstall().installPromptEnabled) {
      PWAInstall().promptInstall_();
    }

    if (state.isLoading) return;

    // ── Client-side validation ──
    final errors = <String, List<String>>{};
    if (state.username.isEmpty) errors['username'] = ['This field is required'];
    if (state.password.isEmpty) errors['password'] = ['This field is required'];
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, clearErrors: true);

    try {
      final auth = _ref.read(authRepositoryProvider);
      final result = await auth.login(
        username: state.username,
        password: state.password,
      );

      // Update global auth state → triggers navigation.
      _ref.read(authProvider.notifier).updateEmployee(result.employee);
      _ref.read(authProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        employee: result.employee,
      );
    } on ValidationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
        fieldErrors: e.fieldErrors,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
      );
    }
  }
}

final loginFormProvider =
    StateNotifierProvider.autoDispose<LoginFormController, LoginFormState>(
      (ref) => LoginFormController(ref),
    );

// ═══════════════════════════════════════════════════════════════════
// Logout Action
// ═══════════════════════════════════════════════════════════════════

/// Performs logout then clears auth state.
final logoutProvider = FutureProvider.autoDispose.family<void, bool>((
  ref,
  logoutAll,
) async {
  final auth = ref.read(authRepositoryProvider);
  if (logoutAll) {
    await auth.logoutAll();
  } else {
    await auth.logout();
  }
  ref.read(authProvider.notifier).onLogout();
});
