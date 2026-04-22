import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/task_details_model.dart';

/// Immutable snapshot of the Details tab.
class TaskDetailsState {
  final TaskDetails? details;
  final bool isLoading;
  final bool isSaving;
  final bool isDeleting;
  final String? error;

  const TaskDetailsState({
    this.details,
    this.isLoading = false,
    this.isSaving = false,
    this.isDeleting = false,
    this.error,
  });

  TaskDetailsState copyWith({
    TaskDetails? details,
    bool? isLoading,
    bool? isSaving,
    bool? isDeleting,
    Object? error = _sentinel,
  }) {
    return TaskDetailsState(
      details: details ?? this.details,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// Owns the Details tab data flow for a single task.
///
/// Every async method guards its writes with `if (!mounted) return;`
/// so a rapid tab switch (which disposes the autoDispose controller)
/// never triggers a Bad-state crash when the in-flight HTTP call
/// eventually resolves.
class TaskDetailsController extends StateNotifier<TaskDetailsState> {
  final Ref _ref;
  final int taskId;

  TaskDetailsController(this._ref, this.taskId)
      : super(const TaskDetailsState());

  // ── Loading ────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final data = await repo.getTaskDetails(taskId);
      if (!mounted) return;
      state = state.copyWith(
        details: data,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────

  /// Apply a partial update. `changes` is the raw PATCH body — only
  /// include keys the user actually changed. On success the state is
  /// replaced with the fresh [TaskDetails] returned by the server (no
  /// extra round-trip). On failure the exception is re-thrown so the
  /// caller can route it through [GlobalErrorHandler].
  Future<void> patch(Map<String, dynamic> changes) async {
    if (!mounted) return;
    if (changes.isEmpty) return; // nothing to do
    state = state.copyWith(isSaving: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final updated = await repo.patchTaskDetails(taskId, changes);
      if (!mounted) return;
      state = state.copyWith(details: updated, isSaving: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isSaving: false, error: e.toString());
      }
      rethrow;
    }
  }

  /// Soft-delete the task. The caller should navigate away on success;
  /// this controller doesn't know the router.
  Future<void> delete() async {
    if (!mounted) return;
    state = state.copyWith(isDeleting: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.deleteTask(taskId);
      // State is about to be disposed when the screen closes; no need
      // to flip `isDeleting` back.
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isDeleting: false, error: e.toString());
      }
      rethrow;
    }
  }
}

final taskDetailsProvider = StateNotifierProvider.autoDispose
    .family<TaskDetailsController, TaskDetailsState, int>(
  (ref, taskId) => TaskDetailsController(ref, taskId),
);
