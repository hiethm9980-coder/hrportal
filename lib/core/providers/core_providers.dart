/// Bridges GetIt data-layer singletons into Riverpod.
///
/// The data layer uses GetIt (injection.dart). The presentation layer
/// uses Riverpod. This file provides the bridge — each repository and
/// core service is exposed as a Riverpod Provider that reads from GetIt.
///
/// ⚠️ DO NOT modify data layer injection.dart. Only read from it here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../injection.dart';
import '../../core/network/session_manager.dart';
import '../../core/storage/secure_token_storage.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/profile/data/repositories/profile_repository.dart';
import '../../features/attendance/data/repositories/attendance_repository.dart';
import '../../features/leave/data/repositories/leave_repository.dart';
import '../../core/services/attachment_service.dart';
import '../../features/payroll/data/repositories/payroll_repository.dart';
import '../../features/requests/data/repositories/request_repository.dart';
import '../../features/manager_requests/data/repositories/manager_request_repository.dart';
import '../../features/holidays/data/repositories/holiday_repository.dart';
import '../../features/manager_requests/data/repositories/manager_leave_repository.dart';

// ── Core Services ────────────────────────────────────────────────────
final sessionManagerProvider = Provider<SessionManager>(
  (_) => sl<SessionManager>(),
);

final secureStorageProvider = Provider<SecureTokenStorage>(
  (_) => sl<SecureTokenStorage>(),
);

// ── Repositories ─────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>(
  (_) => sl<AuthRepository>(),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => sl<ProfileRepository>(),
);

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (_) => sl<AttendanceRepository>(),
);

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (_) => sl<LeaveRepository>(),
);

final attachmentServiceProvider = Provider<AttachmentService>(
  (_) => AttachmentService(storage: sl<SecureTokenStorage>()),
);

final payrollRepositoryProvider = Provider<PayrollRepository>(
  (_) => sl<PayrollRepository>(),
);

final requestRepositoryProvider = Provider<RequestRepository>(
  (_) => sl<RequestRepository>(),
);

final managerRequestRepositoryProvider =
    Provider<ManagerRequestRepository>(
  (_) => sl<ManagerRequestRepository>(),
);

final managerLeaveRepositoryProvider =
    Provider<ManagerLeaveRepository>(
  (_) => sl<ManagerLeaveRepository>(),
);

final holidayRepositoryProvider = Provider<HolidayRepository>(
  (_) => sl<HolidayRepository>(),
);
