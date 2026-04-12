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

  // ── API Version Prefix ─────────────────────────────────────────────
  static const String _v1 = '/api/v1';

  // ── Auth ────────────────────────────────────────────────────────────
  static const String login = '$_v1/auth/login';
  static const String logout = '$_v1/auth/logout';
  static const String logoutAll = '$_v1/auth/logout-all';
  static const String me = '$_v1/auth/me';
  static const String changePassword = '$_v1/change-password';

  // ── Profile ─────────────────────────────────────────────────────────
  static const String profile = '$_v1/employee/profile';

  // ── Attendance ──────────────────────────────────────────────────────
  static const String checkIn = '$_v1/attendance/check-in';
  static const String checkOut = '$_v1/attendance/check-out';
  static const String attendanceHistory = '$_v1/attendance/history';

  // ── Leave Balances ──────────────────────────────────────────────────
  static const String leaveBalances = '$_v1/leave-balances';

  // ── Leave Requests ──────────────────────────────────────────────────
  static const String leaveRequests = '$_v1/leave-requests';
  static const String leaveRequestsSummary = '$_v1/leave-requests/summary';
  static String leaveRequestDetail(int id) => '$_v1/leave-requests/$id';
  static String leaveRequestSubmit(int id) => '$_v1/leave-requests/$id/submit';
  static String leaveRequestDelete(int id) => '$_v1/leave-requests/$id';

  // ── Payroll ─────────────────────────────────────────────────────────
  static const String payroll = '$_v1/payroll';
  static String payslipDetail(String month) => '$_v1/payroll/$month';

  // ── Employee Requests ───────────────────────────────────────────────
  static const String requests = '$_v1/requests';
  static const String employeeRequestTypes = '$_v1/employee-request-types';
  static const String currencies = '$_v1/currencies';
  static const String employeeRequests = '$_v1/employee-requests';
  static const String employeeRequestsSummary = '$_v1/employee-requests/summary';
  static String employeeRequestDetail(int id) => '$_v1/employee-requests/$id';
  static String employeeRequestSubmit(int id) => '$_v1/employee-requests/$id/submit';
  static String employeeRequestDelete(int id) => '$_v1/employee-requests/$id';

  // ── Approvals ─────────────────────────────────────────────────────
  // Other (employee) requests — backend exposes separate approve/reject
  // endpoints (no /decide alias for this resource).
  static const String managerRequests = '$_v1/approvals/requests';
  static String managerRequestDetail(int id) => '$_v1/approvals/requests/$id';
  static String managerRequestApprove(int id) =>
      '$_v1/approvals/requests/$id/approve';
  static String managerRequestReject(int id) =>
      '$_v1/approvals/requests/$id/reject';

  // Leave requests — backend exposes /approve, /reject AND a /decide alias.
  static const String managerLeaves = '$_v1/approvals/leaves';
  static String managerLeaveDetail(int id) => '$_v1/approvals/leaves/$id';
  static String managerLeaveDecide(int id) =>
      '$_v1/approvals/leaves/$id/decide';

  // ── Booked Days (calendar overlap prevention) ─────────────────────
  static const String bookedDays = '$_v1/leave-requests/booked-days';

  // ── Holidays ──────────────────────────────────────────────────────
  static const String holidays = '$_v1/holidays';
}
