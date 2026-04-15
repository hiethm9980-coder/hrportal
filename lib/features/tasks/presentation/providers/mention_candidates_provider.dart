import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/comment_models.dart';

/// State of the @-popup data fetch for one task.
class MentionCandidatesState {
  final List<MentionCandidate> items;
  final String query;
  final bool isLoading;
  final String? error;

  const MentionCandidatesState({
    this.items = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
  });

  MentionCandidatesState copyWith({
    List<MentionCandidate>? items,
    String? query,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return MentionCandidatesState(
      items: items ?? this.items,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// Owns the @-popup state for a single task.
///
/// The candidate list is server-filtered: each query change triggers a
/// fresh request with `?q=`. We deliberately don't debounce here — the
/// composer widget already debounces keystrokes before calling [setQuery].
class MentionCandidatesController
    extends StateNotifier<MentionCandidatesState> {
  final Ref _ref;
  final int taskId;

  /// Bumped on every fetch so a stale response from an earlier query can be
  /// discarded if a newer one started in the meantime.
  int _requestSeq = 0;

  MentionCandidatesController(this._ref, this.taskId)
      : super(const MentionCandidatesState());

  /// Fetch the full list (no filter). Call once when the @ popup opens.
  Future<void> loadInitial() => setQuery('');

  /// Fetch candidates filtered by [q] (server-side `LIKE` over name/code).
  Future<void> setQuery(String q) async {
    final seq = ++_requestSeq;
    state = state.copyWith(query: q, isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final data = await repo.listMentionCandidates(taskId, q: q);
      // Drop stale responses — if the user typed faster than the network,
      // _requestSeq has already moved on and our payload is outdated.
      if (seq != _requestSeq) return;
      state = state.copyWith(items: data.items, isLoading: false, error: null);
    } catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Reset to empty so the next open of the popup starts clean.
  void reset() {
    _requestSeq++;
    state = const MentionCandidatesState();
  }
}

final mentionCandidatesProvider = StateNotifierProvider.autoDispose
    .family<MentionCandidatesController, MentionCandidatesState, int>(
  (ref, taskId) => MentionCandidatesController(ref, taskId),
);
