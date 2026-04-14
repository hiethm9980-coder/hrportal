import 'package:get_it/get_it.dart';

import 'core/network/api_client.dart';
import 'core/network/session_manager.dart';
import 'core/storage/secure_token_storage.dart';
import 'features/attendance/data/repositories/attendance_repository.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/leave/data/repositories/leave_repository.dart';
import 'features/payroll/data/repositories/payroll_repository.dart';
import 'features/profile/data/repositories/profile_repository.dart';
import 'features/requests/data/repositories/request_repository.dart';
import 'features/manager_requests/data/repositories/manager_request_repository.dart';
import 'features/holidays/data/repositories/holiday_repository.dart';
import 'features/manager_requests/data/repositories/manager_leave_repository.dart';
import 'features/tasks/data/repositories/project_repository.dart';
import 'features/tasks/data/repositories/task_repository.dart';

final sl = GetIt.instance;

/// Initialize all dependencies.
///
/// Call this once in `main()` before `runApp()`.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initDependencies();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initDependencies() async {
  // ── Core: Storage ──────────────────────────────────────────────────
  sl.registerLazySingleton<SecureTokenStorage>(
    () => SecureTokenStorage(),
  );

  // ── Core: Session Manager ──────────────────────────────────────────
  sl.registerLazySingleton<SessionManager>(
    () => SessionManager(storage: sl<SecureTokenStorage>()),
  );

  // ── Core: API Client ───────────────────────────────────────────────
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      storage: sl<SecureTokenStorage>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  // ── Feature: Auth ──────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      client: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  // ── Feature: Profile ───────────────────────────────────────────────
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Attendance ────────────────────────────────────────────
  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Leave ─────────────────────────────────────────────────
  sl.registerLazySingleton<LeaveRepository>(
    () => LeaveRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Payroll ───────────────────────────────────────────────
  sl.registerLazySingleton<PayrollRepository>(
    () => PayrollRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Requests ──────────────────────────────────────────────
  sl.registerLazySingleton<RequestRepository>(
    () => RequestRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Manager Requests (Approvals) ────────────────────────
  sl.registerLazySingleton<ManagerRequestRepository>(
    () => ManagerRequestRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Manager Leaves (Approvals) ─────────────────────────
  sl.registerLazySingleton<ManagerLeaveRepository>(
    () => ManagerLeaveRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Holidays ──────────────────────────────────────────────
  sl.registerLazySingleton<HolidayRepository>(
    () => HolidayRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Tasks ─────────────────────────────────────────────────
  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepository(client: sl<ApiClient>()),
  );

  // ── Feature: Projects (brief list for task filters) ──────────────
  sl.registerLazySingleton<ProjectRepository>(
    () => ProjectRepository(client: sl<ApiClient>()),
  );
}
