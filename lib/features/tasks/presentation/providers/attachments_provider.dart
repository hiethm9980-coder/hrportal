import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/attachment_models.dart';

/// Immutable snapshot of the Attachments tab.
class AttachmentsState {
  final AttachmentsSummary summary;

  /// Server returns newest first. We keep that ordering in state and let
  /// the UI reverse it for the WhatsApp-style chronological layout, so
  /// splicing a just-uploaded file is a trivial `[new, ...old]`.
  final List<TaskAttachment> attachments;

  final bool isLoading;
  final bool isUploading;
  final bool isMutating;
  final String? error;

  const AttachmentsState({
    this.summary = const AttachmentsSummary(),
    this.attachments = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.isMutating = false,
    this.error,
  });

  AttachmentsState copyWith({
    AttachmentsSummary? summary,
    List<TaskAttachment>? attachments,
    bool? isLoading,
    bool? isUploading,
    bool? isMutating,
    Object? error = _sentinel,
  }) {
    return AttachmentsState(
      summary: summary ?? this.summary,
      attachments: attachments ?? this.attachments,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      isMutating: isMutating ?? this.isMutating,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// Owns the Attachments tab data flow for a single task.
///
/// All async code paths guard writes with `if (!mounted) return;` so a
/// fast tab switch (which disposes the `autoDispose.family` controller)
/// never triggers a Bad-state crash when the pending HTTP call resolves.
class AttachmentsController extends StateNotifier<AttachmentsState> {
  final Ref _ref;
  final int taskId;

  AttachmentsController(this._ref, this.taskId)
      : super(const AttachmentsState());

  // ── Loading ────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final data = await repo.listAttachments(taskId);
      if (!mounted) return;
      state = state.copyWith(
        summary: data.summary,
        attachments: data.attachments,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────

  /// Upload a file then splice the returned attachment into the local
  /// list (newest first) + bump the count. No full reload needed.
  Future<void> upload({
    required String filePath,
    String? filename,
  }) async {
    if (!mounted) return;
    state = state.copyWith(isUploading: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      final created = await repo.uploadAttachment(
        taskId,
        filePath: filePath,
        filename: filename,
      );
      if (!mounted) return;
      state = state.copyWith(
        attachments: [created, ...state.attachments],
        summary: AttachmentsSummary(
          count: state.summary.count + 1,
          canUpload: state.summary.canUpload,
        ),
        isUploading: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isUploading: false, error: e.toString());
      }
      rethrow;
    }
  }

  /// Remove an attachment then patch the local list optimistically.
  Future<void> delete(int attachmentId) async {
    if (!mounted) return;
    state = state.copyWith(isMutating: true, error: null);
    try {
      final repo = _ref.read(taskRepositoryProvider);
      await repo.deleteAttachment(taskId, attachmentId);
      if (!mounted) return;
      final remaining =
          state.attachments.where((a) => a.id != attachmentId).toList();
      state = state.copyWith(
        attachments: remaining,
        summary: AttachmentsSummary(
          count: remaining.length,
          canUpload: state.summary.canUpload,
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

/// Family keyed by taskId — each detail screen gets its own state.
final attachmentsProvider = StateNotifierProvider.autoDispose
    .family<AttachmentsController, AttachmentsState, int>(
  (ref, taskId) => AttachmentsController(ref, taskId),
);
