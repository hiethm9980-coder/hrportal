import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/time_log_models.dart';

/// Filter snapshot for the Time Logs tab.
///
/// The only user-driven filters on this screen are:
/// - the search field (`q`)
/// - the chip row (`statusCode`, defaults to `'all'`)
///
/// `all` is the sentinel used by the backend — we keep the same string here
/// so there's no code/UX divergence.
class TimeLogsFilter {
  final String q;
  final String statusCode;

  const TimeLogsFilter({
    this.q = '',
    this.statusCode = 'all',
  });

  TimeLogsFilter copyWith({String? q, String? statusCode}) {
    return TimeLogsFilter(
      q: q ?? this.q,
      statusCode: statusCode ?? this.statusCode,
    );
  }
}

/// Immutable snapshot of the Time Logs tab.
class TimeLogsState {
  final TimeLogsFilter filter;
  final TimeLogSummary summary;
  final TimeLogStatusBreakdown statusBreakdown;
  final List<TimeLog> logs;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  const TimeLogsState({
    this.filter = const TimeLogsFilter(),
    this.summary = const TimeLogSummary(),
    this.statusBreakdown = const TimeLogStatusBreakdown(),
    this.logs = const [],
    this.isLoading = false,
    this.isMutating = false,
    this.error,
  });

  TimeLogsState copyWith({
    TimeLogsFilter? filter,
    TimeLogSummary? summary,
    TimeLogStatusBreakdown? statusBreakdown,
    List<TimeLog>? logs,
    bool? isLoading,
    bool? isMutating,
    Object? error = _sentinel,
  }) {
    return TimeLogsState(
      filter: filter ?? this.filter,
      summary: summary ?? this.summary,
      statusBreakdown: statusBreakdown ?? this.statusBreakdown,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// Owns the Time Logs tab data flow for a single task.
class TimeLogsController extends StateNotifier<TimeLogsState> {
  final Ref _ref;
  final int taskId;

  TimeLogsController(this._ref, this.taskId) : super(const TimeLogsState());

  // ── Filter mutators ─────────────────────────────────────────────────

  void setSearch(String q) {
    if (state.filter.q == q) return;
    state = state.copyWith(filter: state.filter.copyWith(q: q));
    load();
  }

  void setStatus(String code) {
    if (state.filter.statusCode == code) return;
    state = state.copyWith(filter: state.filter.copyWith(statusCode: code));
    load();
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final f = state.filter;
      final data = await repo.listTimeLogs(
        taskId,
        q: f.q,
        status: f.statusCode,
      );
      state = state.copyWith(
        summary: data.summary,
        statusBreakdown: data.statusBreakdown,
        logs: data.logs,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Mutations ───────────────────────────────────────────────────────

  /// Create a new time log then reload the list so totals, chip counts, and
  /// per-log status all stay in sync with the server.
  Future<void> createLog({
    required String dateFrom,
    String? dateTo,
    required double hoursSpent,
    String? description,
    int? employeeId,
  }) async {
    state = state.copyWith(isMutating: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.createTimeLog(
        taskId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        hoursSpent: hoursSpent,
        description: description,
        employeeId: employeeId,
      );
      await load();
      state = state.copyWith(isMutating: false);
    } catch (e) {
      state = state.copyWith(isMutating: false, error: e.toString());
      rethrow;
    }
  }

  /// Delete a single log. The UI guards this behind `log.canDelete`, but the
  /// server is the ultimate authority.
  Future<void> deleteLog(int logId) async {
    state = state.copyWith(isMutating: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.deleteTimeLog(taskId, logId);
      await load();
      state = state.copyWith(isMutating: false);
    } catch (e) {
      state = state.copyWith(isMutating: false, error: e.toString());
      rethrow;
    }
  }
}

/// Family keyed by taskId — each open detail screen gets its own state so
/// two simultaneous tabs don't stomp on each other.
final timeLogsProvider = StateNotifierProvider.autoDispose
    .family<TimeLogsController, TimeLogsState, int>(
  (ref, taskId) => TimeLogsController(ref, taskId),
);
