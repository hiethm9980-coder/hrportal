import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/task_models.dart';
import 'company_list_scope_provider.dart';

/// Filter snapshot for the subtasks list. Mirrors the My Tasks filter but
/// deliberately omits `projectId` (subtasks always inherit the parent's
/// project) and `assigneeId` (subtasks of a parent can be assigned to anyone
/// — no built-in "assigned to me" restriction on this screen).
class SubtasksFilter {
  final String q;
  final String? statusCode;
  final String? priorityCode;
  final bool overdueOnly;
  final bool openOnly;
  final String? dueFrom;
  final String? dueTo;

  const SubtasksFilter({
    this.q = '',
    this.statusCode,
    this.priorityCode,
    this.overdueOnly = false,
    this.openOnly = false,
    this.dueFrom,
    this.dueTo,
  });

  SubtasksFilter copyWith({
    String? q,
    Object? statusCode = _sentinel,
    Object? priorityCode = _sentinel,
    bool? overdueOnly,
    bool? openOnly,
    Object? dueFrom = _sentinel,
    Object? dueTo = _sentinel,
  }) {
    return SubtasksFilter(
      q: q ?? this.q,
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
    );
  }

  /// Filters hidden behind the tune icon — same semantics as the My Tasks
  /// `hasAdvancedFilters` flag.
  bool get hasAdvancedFilters =>
      (priorityCode != null && priorityCode!.isNotEmpty) ||
      overdueOnly ||
      openOnly ||
      (dueFrom != null && dueFrom!.isNotEmpty) ||
      (dueTo != null && dueTo!.isNotEmpty);
}

const _sentinel = Object();

class SubtasksState {
  final SubtasksFilter filter;
  final Task? parent;
  /// From [GET /tasks/{id}/subtasks] root `permissions.can_create_subtask` (not only `parent.permissions`).
  final bool canCreateSubtask;
  final List<Task> items;
  final TaskStats stats;
  final StatusBreakdown statusBreakdown;
  final PaginationInfo pagination;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMutating;
  final String? error;

  const SubtasksState({
    this.filter = const SubtasksFilter(),
    this.parent,
    this.canCreateSubtask = false,
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

  SubtasksState copyWith({
    SubtasksFilter? filter,
    Task? parent,
    bool? canCreateSubtask,
    List<Task>? items,
    TaskStats? stats,
    StatusBreakdown? statusBreakdown,
    PaginationInfo? pagination,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMutating,
    Object? error = _sentinel,
  }) {
    return SubtasksState(
      filter: filter ?? this.filter,
      parent: parent ?? this.parent,
      canCreateSubtask: canCreateSubtask ?? this.canCreateSubtask,
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

class SubtasksController extends StateNotifier<SubtasksState> {
  final Ref _ref;
  final int parentTaskId;
  static const int _perPage = 50;

  SubtasksController(this._ref, this.parentTaskId)
      : super(const SubtasksState());

  // ── Filter mutators ─────────────────────────────────────────────────

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

  void applyAdvancedFilters({
    String? priorityCode,
    bool overdueOnly = false,
    bool openOnly = false,
    String? dueFrom,
    String? dueTo,
  }) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        priorityCode: priorityCode,
        overdueOnly: overdueOnly,
        openOnly: openOnly,
        dueFrom: dueFrom,
        dueTo: dueTo,
      ),
    );
    load(reset: true);
  }

  void clearFilters({bool full = false}) {
    state = state.copyWith(
      filter: full
          ? const SubtasksFilter()
          : state.filter.copyWith(
              priorityCode: null,
              overdueOnly: false,
              openOnly: false,
              dueFrom: null,
              dueTo: null,
            ),
    );
    load(reset: true);
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> load({bool reset = true}) async {
    // autoDispose guard: the controller may have been disposed while the
    // HTTP request was in flight (fast tab switching). Touching `state`
    // after disposal throws a Bad-state crash.
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final filter = state.filter;
      final companyId = _ref.read(companyListScopeIdProvider);
      final data = await repo.listSubtasks(
        parentTaskId,
        q: filter.q,
        status: filter.statusCode,
        priority: filter.priorityCode,
        overdue: filter.overdueOnly,
        dueFrom: filter.dueFrom,
        dueTo: filter.dueTo,
        companyId: companyId,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) return;

      var items = data.subtasks;
      if (filter.openOnly) {
        items = items
            .where((t) => (t.status?.category ?? 'OPEN') != 'DONE')
            .toList();
      }

      final allowSub =
          data.permissions.canCreateSubtask ||
              (data.parent.permissions?.canCreateSubtask == true);

      state = state.copyWith(
        parent: data.parent,
        canCreateSubtask: allowSub,
        items: items,
        stats: data.stats,
        statusBreakdown: data.statusBreakdown,
        pagination: data.pagination,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        items: reset ? const [] : state.items,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore) return;
    if (!state.pagination.hasMore) return;

    if (!mounted) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final filter = state.filter;
      final nextPage = state.pagination.currentPage + 1;
      final companyId = _ref.read(companyListScopeIdProvider);
      final data = await repo.listSubtasks(
        parentTaskId,
        q: filter.q,
        status: filter.statusCode,
        priority: filter.priorityCode,
        overdue: filter.overdueOnly,
        dueFrom: filter.dueFrom,
        dueTo: filter.dueTo,
        companyId: companyId,
        page: nextPage,
        perPage: _perPage,
      );
      if (!mounted) return;

      var newItems = data.subtasks;
      if (filter.openOnly) {
        newItems = newItems
            .where((t) => (t.status?.category ?? 'OPEN') != 'DONE')
            .toList();
      }

      state = state.copyWith(
        items: [...state.items, ...newItems],
        pagination: data.pagination,
        stats: data.stats,
        statusBreakdown: data.statusBreakdown,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  // ── Mutations (apply to any task in the tree: parent OR subtask) ────

  /// Update a task's status. If [taskId] matches the parent, the parent
  /// field is patched (so the header status dropdown reflects the change
  /// without a full reload); otherwise the matching subtask in the list
  /// is reloaded.
  Future<void> updateStatus({
    required int taskId,
    required String statusCode,
  }) async {
    if (!mounted) return;
    state = state.copyWith(isMutating: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.updateStatus(taskId, statusCode);
      if (!mounted) return;
      // The cheapest way to reconcile parent + list + counts after a status
      // change is a single reload — statuses move tasks between columns
      // and also bump breakdown counts.
      await load(reset: true);
      if (!mounted) return;
      state = state.copyWith(isMutating: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isMutating: false, error: e.toString());
      }
      rethrow;
    }
  }

  /// Optimistic progress update for either the parent or a subtask.
  Future<TaskProgressResult> updateProgress({
    required int taskId,
    required int percent,
    required int previousPercent,
  }) async {
    if (!mounted) {
      // Still need to return *something* — callers await us. Synthesize a
      // neutral result so the await resolves without touching `state`.
      return TaskProgressResult(
        taskId: taskId,
        progressPercent: percent,
        newStatus: null,
        isCompleted: percent >= 100,
        statusChanged: false,
      );
    }
    final isParent = state.parent?.id == taskId;

    // 1. Optimistic local patch.
    state = state.copyWith(
      parent: isParent
          ? state.parent?.copyWith(progress: percent)
          : state.parent,
      items: [
        for (final t in state.items)
          if (t.id == taskId) t.copyWith(progress: percent) else t,
      ],
    );

    try {
      final repo = _ref.read(taskRepositoryProvider);
      final result = await repo.updateProgress(taskId, percent);
      if (!mounted) return result;

      // 2. Reconcile with server payload.
      state = state.copyWith(
        parent: isParent
            ? state.parent?.copyWith(
                progress: result.progressPercent,
                status: result.statusChanged ? result.newStatus : state.parent?.status,
              )
            : state.parent,
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
      // 3. Rollback — only if we're still mounted; otherwise just surface
      // the error.
      if (!mounted) rethrow;
      state = state.copyWith(
        parent: isParent
            ? state.parent?.copyWith(progress: previousPercent)
            : state.parent,
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

/// Family provider keyed by parent task id — each open detail screen gets
/// its own controller so simultaneously open details never clash.
///
/// `autoDispose` so leaving the screen frees the memory. If we later want
/// to cache between navigations we can switch to a `.keepAlive()` family.
final subtasksProvider = StateNotifierProvider.autoDispose
    .family<SubtasksController, SubtasksState, int>(
  (ref, parentTaskId) => SubtasksController(ref, parentTaskId),
);
