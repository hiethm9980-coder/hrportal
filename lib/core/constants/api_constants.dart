// ⚠️ API CONTRACT v1.0.0 — Paths must match docs/api/hr_mobile_v1_contract.md exactly.


import 'package:hr_portal/core/config/app_config.dart';

/// API configuration constants.
///
/// All paths are relative to [baseUrl] and match the frozen contract v1.0.0.
/// Do NOT change any path without a corresponding API version bump.
class ApiConstants {
  ApiConstants._();

  // ── Server ─────────────────────────────────────────────────────────
  // Base URL is resolved from AppConfig (--dart-define=FLAVOR).
  // Call ApiConstants.configure() once in main.dart after AppConfig init.
  static late String baseUrl;

  /// Initialize baseUrl from environment config.
  /// Must be called once in main() before any API calls.
  static void configure(AppConfig config) {
    baseUrl = config.baseUrl;
  }

  // ── Contract Version ───────────────────────────────────────────────
  static const String contractVersion = '1.0.0';
  static const String versionHeader = 'X-API-Version';
  static const String traceIdHeader = 'X-Trace-Id';

  // ── Timeouts (milliseconds) ────────────────────────────────────────
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  static const int sendTimeout = 10000;

  // ── Auth ────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String me = '/me';
  static const String changePassword = '/change-password';

  // ── Profile ─────────────────────────────────────────────────────────
  static const String profile = '/employee/profile';

  // ── Attendance ──────────────────────────────────────────────────────
  static const String checkIn = '/attendance/check-in';
  static const String checkOut = '/attendance/check-out';
  static const String attendanceHistory = '/attendance/history';

  // ── Leave Balances ──────────────────────────────────────────────────
  static const String leaveBalances = '/leave-balances';

  // ── Leave Requests ──────────────────────────────────────────────────
  static const String leaveRequests = '/leave-requests';
  static const String leaveRequestsSummary = '/leave-requests/summary';
  static String leaveRequestDetail(int id) => '/leave-requests/$id';
  static String leaveRequestSubmit(int id) => '/leave-requests/$id/submit';
  static String leaveRequestDelete(int id) => '/leave-requests/$id';

  // ── Payroll ─────────────────────────────────────────────────────────
  static const String payroll = '/payroll';
  static String payslipDetail(String month) => '/payroll/$month';

  // ── Employee Requests ───────────────────────────────────────────────
  static const String requests = '/requests';

  // ── Manager Requests (Approvals) ──────────────────────────────────
  static const String managerRequests = '/manager/requests';
  static String managerRequestDetail(int id) => '/manager/requests/$id';
  static String managerRequestDecide(int id) => '/manager/requests/$id/decide';

  // ── Manager Leaves (Approvals) ──────────────────────────────────
  static const String managerLeaves = '/manager/leaves';
  static String managerLeaveDetail(int id) => '/manager/leaves/$id';
  static String managerLeaveDecide(int id) => '/manager/leaves/$id/decide';
}
