import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/task_models.dart';
import 'company_list_scope_provider.dart' show companyListScopeIdProvider;

/// Immutable filter snapshot.
///
/// All fields are optional except [perPage]. The server combines them with
/// AND logic. The status filter is applied to the task list but deliberately
/// does *not* affect the `status_breakdown` counts returned by the backend.
class TaskFilter {
  final String q;
  final int? projectId;
  final String? statusCode;    // null => "All" chip selected
  final String? priorityCode;  // LOW | MEDIUM | HIGH | CRITICAL
  final bool overdueOnly;
  final bool openOnly;
  final String? dueFrom;       // yyyy-MM-dd
  final String? dueTo;         // yyyy-MM-dd
  /// When true, API sends `assignee_id=me`. Default false — full relevant list.
  final bool assigneeOnlyMe;

  const TaskFilter({
    this.q = '',
    this.projectId,
    this.statusCode,
    this.priorityCode,
    this.overdueOnly = false,
    this.openOnly = false,
    this.dueFrom,
    this.dueTo,
    this.assigneeOnlyMe = false,
  });

  TaskFilter copyWith({
    String? q,
    Object? projectId = _sentinel,
    Object? statusCode = _sentinel,
    Object? priorityCode = _sentinel,
    bool? overdueOnly,
    bool? openOnly,
    Object? dueFrom = _sentinel,
    Object? dueTo = _sentinel,
    Object? assigneeOnlyMe = _sentinel,
  }) {
    return TaskFilter(
      q: q ?? this.q,
      projectId: identical(projectId, _sentinel)
          ? this.projectId
          : projectId as int?,
      statusCode: identical(statusCode, _sentinel)
          ? this.statusCode
          : statusCode as String?,
      priorityCode: identical(priorityCode, _sentinel)
          ? this.priorityCode
          : priorityCode as String?,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      openOnly: openOnly ?? this.openOnly,
      dueFrom: identical(dueFrom, _sentinel) ? this.dueFrom : dueFrom as String?,
      dueTo: identical(dueTo, _sentinel) ? this.dueTo : dueTo as String?,
      assigneeOnlyMe: identical(assigneeOnlyMe, _sentinel)
          ? this.assigneeOnlyMe
          : assigneeOnlyMe as bool,
    );
  }

  /// Whether the user has any filter set inside the *advanced filter sheet*.
  ///
  /// Deliberately excludes [projectId], [q], and [statusCode] — those each
  /// have their own dedicated, always-visible control in the header
  /// (project dropdown, search box, status chips). The yellow dot on the
  /// filter icon should only indicate filters hidden *behind* that icon.
  bool get hasAdvancedFilters =>
      assigneeOnlyMe ||
      (priorityCode != null && priorityCode!.isNotEmpty) ||
      overdueOnly ||
      openOnly ||
      (dueFrom != null && dueFrom!.isNotEmpty) ||
      (dueTo != null && dueTo!.isNotEmpty);
}

const _sentinel = Object();

class MyTasksState {
  final TaskFilter filter;
  final List<Task> items;
  final TaskStats stats;
  final StatusBreakdown statusBreakdown;
  final PaginationInfo pagination;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMutating; // true while a status update is in flight
  final String? error;

  const MyTasksState({
    this.filter = const TaskFilter(),
    this.items = const [],
    this.stats = const TaskStats(),
    this.statusBreakdown = const StatusBreakdown(),
    this.pagination = const PaginationInfo(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isMutating = false,
    this.error,
  });

  bool get hasMore => pagination.hasMore;

  MyTasksState copyWith({
    TaskFilter? filter,
    List<Task>? items,
    TaskStats? stats,
    StatusBreakdown? statusBreakdown,
    PaginationInfo? pagination,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMutating,
    Object? error = _sentinel,
  }) {
    return MyTasksState(
      filter: filter ?? this.filter,
      items: items ?? this.items,
      stats: stats ?? this.stats,
      statusBreakdown: statusBreakdown ?? this.statusBreakdown,
      pagination: pagination ?? this.pagination,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMutating: isMutating ?? this.isMutating,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class MyTasksController extends StateNotifier<MyTasksState> {
  final Ref _ref;
  static const int _perPage = 50;

  MyTasksController(this._ref) : super(const MyTasksState());

  // ── Filter mutators ─────────────────────────────────────────────────

  /// Update the free-text search query. The caller should debounce before
  /// invoking this method so we don't spam the server.
  void setSearch(String q) {
    if (state.filter.q == q) return;
    state = state.copyWith(filter: state.filter.copyWith(q: q));
    load(reset: true);
  }

  void setStatus(String? statusCode) {
    if (state.filter.statusCode == statusCode) return;
    state =
        state.copyWith(filter: state.filter.copyWith(statusCode: statusCode));
    load(reset: true);
  }

  void setProject(int? projectId) {
    if (state.filter.projectId == projectId) return;
    state =
        state.copyWith(filter: state.filter.copyWith(projectId: projectId));
    load(reset: true);
  }

  /// Apply the "advanced filter" sheet values in one go. Avoids firing the
  /// network call multiple times when the user tweaks several filters
  /// before tapping Apply.
  void applyAdvancedFilters({
    String? priorityCode,
    bool overdueOnly = false,
    bool openOnly = false,
    String? dueFrom,
    String? dueTo,
    bool assigneeOnlyMe = false,
  }) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        priorityCode: priorityCode,
        overdueOnly: overdueOnly,
        openOnly: openOnly,
        dueFrom: dueFrom,
        dueTo: dueTo,
        assigneeOnlyMe: assigneeOnlyMe,
      ),
    );
    load(reset: true);
  }

  /// Reset every filter except search and status (keeps the current status
  /// chip context so the screen doesn't jump). Pass `full: true` to reset
  /// everything.
  void clearFilters({bool full = false}) {
    state = state.copyWith(
      filter: full
          ? const TaskFilter()
          : state.filter.copyWith(
              projectId: null,
              priorityCode: null,
              overdueOnly: false,
              openOnly: false,
              dueFrom: null,
              dueTo: null,
              assigneeOnlyMe: false,
            ),
    );
    load(reset: true);
  }

  // ── Data loading ────────────────────────────────────────────────────

  /// Load (or reload) the first page of tasks. Pass [reset]=false and no
  /// pagination change to keep the existing list (used for pull-to-refresh).
  Future<void> load({bool reset = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final filter = state.filter;
      final companyId = _ref.read(companyListScopeIdProvider);
      final data = await repo.listTasks(
        q: filter.q,
        projectId: filter.projectId,
        companyId: companyId,
        status: filter.statusCode,
        priority: filter.priorityCode,
        assigneeId: filter.assigneeOnlyMe ? 'me' : null,
        overdue: filter.overdueOnly,
        dueFrom: filter.dueFrom,
        dueTo: filter.dueTo,
        page: 1,
        perPage: _perPage,
      );

      // The backend already orders by updated_at DESC — no client sort needed.
      var items = data.tasks;
      if (filter.openOnly) {
        items = items
            .where((t) => (t.status?.category ?? 'OPEN') != 'DONE')
            .toList();
      }

      state = state.copyWith(
        items: items,
        stats: data.stats,
        statusBreakdown: data.statusBreakdown,
        pagination: data.pagination,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        items: reset ? const [] : state.items,
      );
    }
  }

  /// Fetch the next page and append it to the current list.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore) return;
    if (!state.pagination.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final filter = state.filter;
      final nextPage = state.pagination.currentPage + 1;
      final companyId = _ref.read(companyListScopeIdProvider);
      final data = await repo.listTasks(
        q: filter.q,
        projectId: filter.projectId,
        companyId: companyId,
        status: filter.statusCode,
        priority: filter.priorityCode,
        assigneeId: filter.assigneeOnlyMe ? 'me' : null,
        overdue: filter.overdueOnly,
        dueFrom: filter.dueFrom,
        dueTo: filter.dueTo,
        page: nextPage,
        perPage: _perPage,
      );

      var newItems = data.tasks;
      if (filter.openOnly) {
        newItems = newItems
            .where((t) => (t.status?.category ?? 'OPEN') != 'DONE')
            .toList();
      }

      state = state.copyWith(
        items: [...state.items, ...newItems],
        pagination: data.pagination,
        // status_breakdown / stats may shift if server recounts; prefer latest.
        stats: data.stats,
        statusBreakdown: data.statusBreakdown,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  // ── Mutations ───────────────────────────────────────────────────────

  /// Change a task's status on the server, then reload the list so that the
  /// moved/disappeared task is reflected immediately. The UI is expected to
  /// block interaction while [isMutating] is true.
  Future<void> updateStatus({
    required int taskId,
    required String statusCode,
  }) async {
    state = state.copyWith(isMutating: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.updateStatus(taskId, statusCode);
      // Reload the first page with the current filters so counts stay fresh.
      await load(reset: true);
      state = state.copyWith(isMutating: false);
    } catch (e) {
      state = state.copyWith(isMutating: false, error: e.toString());
      rethrow;
    }
  }

  /// Update the progress slider value on the server.
  ///
  /// Uses an optimistic update: the local task is patched immediately so the
  /// slider stays where the user released it, and we do NOT trigger a full
  /// list reload (the user is still interacting with this card).
  ///
  /// If the server reports `status_changed: true` (progress hit 100 → DONE)
  /// we also patch the local `status` of the task so the status chips row
  /// reflects the auto-transition without a reload.
  ///
  /// On failure the local value is rolled back to [previousPercent].
  Future<TaskProgressResult> updateProgress({
    required int taskId,
    required int percent,
    required int previousPercent,
  }) async {
    // 1. Optimistic local update — slider already moved in the UI.
    state = state.copyWith(
      items: [
        for (final t in state.items)
          if (t.id == taskId) t.copyWith(progress: percent) else t,
      ],
    );

    try {
      final repo = _ref.read(taskRepositoryProvider);
      final result = await repo.updateProgress(taskId, percent);

      // 2. Reconcile with server response: trust server value + status.
      state = state.copyWith(
        items: [
          for (final t in state.items)
            if (t.id == taskId)
              t.copyWith(
                progress: result.progressPercent,
                status: result.statusChanged ? result.newStatus : t.status,
              )
            else
              t,
        ],
      );
      return result;
    } catch (e) {
      // 3. Roll back on failure.
      state = state.copyWith(
        items: [
          for (final t in state.items)
            if (t.id == taskId) t.copyWith(progress: previousPercent) else t,
        ],
        error: e.toString(),
      );
      rethrow;
    }
  }
}

/// Not autoDispose — we want the list to survive across navigation pushes
/// (opening a task detail and coming back).
final myTasksProvider =
    StateNotifierProvider<MyTasksController, MyTasksState>(
  (ref) => MyTasksController(ref),
);
