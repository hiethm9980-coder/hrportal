import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/activity_models.dart';

/// Immutable snapshot of the Activity tab.
class ActivityState {
  final ActivitySummary summary;

  /// Server order — newest first. Used verbatim by the UI.
  final List<ActivityItem> items;

  final bool isLoading;
  final String? error;

  const ActivityState({
    this.summary = const ActivitySummary(),
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ActivityState copyWith({
    ActivitySummary? summary,
    List<ActivityItem>? items,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return ActivityState(
      summary: summary ?? this.summary,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// Owns the Activity tab data flow for a single task.
///
/// Read-only — no mutations needed. The autoDispose guard keeps the
/// controller from crashing when the user switches tabs mid-request.
class ActivityController extends StateNotifier<ActivityState> {
  final Ref _ref;
  final int taskId;

  ActivityController(this._ref, this.taskId) : super(const ActivityState());

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final data = await repo.listActivity(taskId);
      if (!mounted) return;
      state = state.copyWith(
        summary: data.summary,
        items: data.items,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final activityProvider = StateNotifierProvider.autoDispose
    .family<ActivityController, ActivityState, int>(
  (ref, taskId) => ActivityController(ref, taskId),
);
