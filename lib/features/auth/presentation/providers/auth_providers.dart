import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:convert';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../main.dart';
import '../../../profile/data/models/employee_profile_model.dart';
import '../../../../shared/models/approvals_flags.dart';
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
  final ApprovalsFlags? approvals;
  final List<ManagedCompany> managedCompanies;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.employee,
    this.approvals,
    this.managedCompanies = const [],
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get isUnknown => status == AuthStatus.unknown;

  /// Whether the user has manager/approval permissions (legacy flag).
  bool get isManager => employee?.canManageRequests ?? false;

  /// New approvals routing — strictly driven by backend flags.
  /// The Approvals destination and its tabs are shown ONLY when the backend
  /// explicitly says the user has actionable approvals. There is no
  /// `isManager` fallback: a user with the manager role but no real
  /// approvals must NOT see the icon (it would lead to empty screens).
  bool get hasLeaveApprovals => approvals?.hasLeaveApprovals ?? false;
  bool get hasOtherApprovals => approvals?.hasOtherApprovals ?? false;
  bool get hasAnyApprovals => hasLeaveApprovals || hasOtherApprovals;

  AuthState copyWith({
    AuthStatus? status,
    EmployeeProfile? employee,
    ApprovalsFlags? approvals,
    List<ManagedCompany>? managedCompanies,
  }) {
    return AuthState(
      status: status ?? this.status,
      employee: employee ?? this.employee,
      approvals: approvals ?? this.approvals,
      managedCompanies: managedCompanies ?? this.managedCompanies,
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

    // Restore the cached approvals context. The `/auth/me` endpoint may not
    // include `approvals` / `managed_companies` on every backend version, so
    // these values must survive the round-trip even if the server omits them.
    final cachedApprovals = await _loadCachedApprovals(session);
    final cachedCompanies = await _loadCachedManagedCompanies(session);

    // Token exists — validate it with the server.
    try {
      final auth = _ref.read(authRepositoryProvider);
      final me = await auth.getCurrentUser();
      var employee = me.employee;

      // Always apply stored isManager flag if API /me doesn't return it.
      if (!employee.isManager && storedIsManager) {
        employee = employee.copyWith(isManager: true);
      }
      // If API returned it, update storage for next time.
      if (employee.isManager && !storedIsManager) {
        await session.storage.saveIsManager(true);
      }

      // Prefer fresh values from /me, fall back to cache when /me omits them.
      final effectiveApprovals = me.approvals ?? cachedApprovals;
      final effectiveCompanies =
          me.managedCompanies.isNotEmpty ? me.managedCompanies : cachedCompanies;

      // Refresh the cache when /me did provide fresh data.
      if (me.approvals != null) {
        await session.storage
            .saveApprovalsFlagsJson(jsonEncode(me.approvals!.toJson()));
      }
      if (me.managedCompanies.isNotEmpty) {
        await session.storage.saveManagedCompaniesJson(
          jsonEncode(me.managedCompanies.map((e) => e.toJson()).toList()),
        );
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        employee: employee,
        approvals: effectiveApprovals,
        managedCompanies: effectiveCompanies,
      );
    } on TokenExpiredException {
      await session.onLogout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on TokenInvalidException {
      await session.onLogout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on ApiException {
      // Network error — assume authenticated (offline mode), restore the
      // cached approvals context so the UI doesn't lose Approvals visibility.
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
        approvals: cachedApprovals,
        managedCompanies: cachedCompanies,
      );
    }
  }

  Future<ApprovalsFlags?> _loadCachedApprovals(dynamic session) async {
    try {
      final raw = await session.storage.getApprovalsFlagsJson();
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return ApprovalsFlags.fromJson(map);
    } catch (_) {}
    return null;
  }

  Future<List<ManagedCompany>> _loadCachedManagedCompanies(
      dynamic session) async {
    try {
      final raw = await session.storage.getManagedCompaniesJson();
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(ManagedCompany.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Update the stored employee profile (e.g. after profile edit).
  void updateEmployee(EmployeeProfile employee) {
    state = state.copyWith(employee: employee);
  }

  /// Re-fetch `/auth/me` to refresh approval flags and managed-company
  /// counters after the user makes a decision (approve/reject). The backend
  /// does not push these counters, so the app must pull them.
  ///
  /// Silent — failures are ignored to avoid disrupting the calling flow.
  Future<void> refreshApprovalsContext() async {
    if (!state.isAuthenticated) return;
    try {
      final auth = _ref.read(authRepositoryProvider);
      final session = _ref.read(sessionManagerProvider);
      final me = await auth.getCurrentUser();

      // Keep prior values when /me omits these blocks (older backends).
      final nextApprovals = me.approvals ?? state.approvals;
      final nextCompanies = me.managedCompanies.isNotEmpty
          ? me.managedCompanies
          : state.managedCompanies;

      // Refresh the cache so a future cold start doesn't lose them.
      if (me.approvals != null) {
        await session.storage
            .saveApprovalsFlagsJson(jsonEncode(me.approvals!.toJson()));
      }
      if (me.managedCompanies.isNotEmpty) {
        await session.storage.saveManagedCompaniesJson(
          jsonEncode(me.managedCompanies.map((e) => e.toJson()).toList()),
        );
      }

      state = state.copyWith(
        employee: me.employee,
        approvals: nextApprovals,
        managedCompanies: nextCompanies,
      );
    } catch (_) {
      // Stale counters are not worth interrupting the user.
    }
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
      // Fetch base_url from Firebase Remote Config before login
      await appConfig.loadRemoteConfig();
      ApiConstants.configure(appConfig);
      print("base_url: ${appConfig.baseUrl}");

      if (appConfig.baseUrl.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: const UiError(
            title: 'Connection Error',
            message: 'No internet connection',
            action: ErrorAction.showSnackbar,
          ),
        );
        return;
      }

      // Get FCM token (non-blocking, nullable)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
      } catch (_) {}

      final auth = _ref.read(authRepositoryProvider);
      final result = await auth.login(
        username: state.username,
        password: state.password,
        fcmToken: fcmToken,
      );

      // Update global auth state → triggers navigation.
      _ref.read(authProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        employee: result.employee,
        approvals: result.approvals,
        managedCompanies: result.managedCompanies,
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
