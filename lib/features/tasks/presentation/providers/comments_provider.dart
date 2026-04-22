import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/comment_models.dart';

/// Filter snapshot for the Comments tab.
///
/// Only one user-driven filter for now: the optional search field [q]. The
/// rest of the screen is server-driven (count + can_add).
class CommentsFilter {
  final String q;

  const CommentsFilter({this.q = ''});

  CommentsFilter copyWith({String? q}) => CommentsFilter(q: q ?? this.q);
}

/// Immutable snapshot of the Comments tab.
class CommentsState {
  final CommentsFilter filter;
  final CommentsSummary summary;

  /// Server returns newest-first. We KEEP that order in state and let the
  /// UI reverse it for display — that way appending a new comment is a
  /// trivial `[new, ...old]` and the count stays accurate.
  final List<Comment> comments;

  final bool isLoading;
  final bool isSending;
  final bool isMutating;
  final String? error;

  const CommentsState({
    this.filter = const CommentsFilter(),
    this.summary = const CommentsSummary(),
    this.comments = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isMutating = false,
    this.error,
  });

  CommentsState copyWith({
    CommentsFilter? filter,
    CommentsSummary? summary,
    List<Comment>? comments,
    bool? isLoading,
    bool? isSending,
    bool? isMutating,
    Object? error = _sentinel,
  }) {
    return CommentsState(
      filter: filter ?? this.filter,
      summary: summary ?? this.summary,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isMutating: isMutating ?? this.isMutating,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// Owns the Comments tab data flow for a single task.
class CommentsController extends StateNotifier<CommentsState> {
  final Ref _ref;
  final int taskId;

  CommentsController(this._ref, this.taskId) : super(const CommentsState());

  // ── Filter ─────────────────────────────────────────────────────────

  void setSearch(String q) {
    if (state.filter.q == q) return;
    state = state.copyWith(filter: state.filter.copyWith(q: q));
    load();
  }

  // ── Loading ────────────────────────────────────────────────────────

  Future<void> load() async {
    // `autoDispose.family` may have already disposed the controller while
    // this request was in flight (quick tab switch). Guard every write
    // that follows an `await`.
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final data = await repo.listComments(taskId, q: state.filter.q);
      if (!mounted) return;
      state = state.copyWith(
        summary: data.summary,
        comments: data.comments,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────

  /// Send a new comment. The body must already include any
  /// `@[emp:ID|NAME]` tokens for mentions — the composer assembles them by
  /// copying [MentionCandidate.mentionToken] verbatim.
  ///
  /// On success we splice the returned comment into the local list (newest
  /// first) and bump the count; no full reload needed.
  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    if (!mounted) return;
    state = state.copyWith(isSending: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final created = await repo.createComment(taskId, body: trimmed);
      if (!mounted) return;
      state = state.copyWith(
        comments: [created, ...state.comments],
        summary: CommentsSummary(
          count: state.summary.count + 1,
          canAdd: state.summary.canAdd,
        ),
        isSending: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isSending: false, error: e.toString());
      }
      rethrow;
    }
  }

  /// Delete a comment then patch the local list optimistically — the server
  /// is authoritative, but a full reload would feel laggy in a chat UI.
  Future<void> delete(int commentId) async {
    if (!mounted) return;
    state = state.copyWith(isMutating: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.deleteComment(taskId, commentId);
      if (!mounted) return;
      final remaining =
          state.comments.where((c) => c.id != commentId).toList();
      state = state.copyWith(
        comments: remaining,
        summary: CommentsSummary(
          count: remaining.length,
          canAdd: state.summary.canAdd,
        ),
        isMutating: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isMutating: false, error: e.toString());
      }
      rethrow;
    }
  }
}

/// Family keyed by taskId — each open detail screen gets its own state so
/// two simultaneous tabs don't stomp on each other.
final commentsProvider = StateNotifierProvider.autoDispose
    .family<CommentsController, CommentsState, int>(
  (ref, taskId) => CommentsController(ref, taskId),
);
