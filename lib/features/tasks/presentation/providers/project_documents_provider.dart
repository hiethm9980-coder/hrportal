import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/project_document_models.dart';

class ProjectDocumentsState {
  final ProjectDocumentsSummary summary;
  final List<ProjectDocumentItem> documents;
  final bool isLoading;
  final bool isUploading;
  final String? error;

  const ProjectDocumentsState({
    this.summary = const ProjectDocumentsSummary(),
    this.documents = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.error,
  });

  ProjectDocumentsState copyWith({
    ProjectDocumentsSummary? summary,
    List<ProjectDocumentItem>? documents,
    bool? isLoading,
    bool? isUploading,
    Object? error = _sentinel,
  }) {
    return ProjectDocumentsState(
      summary: summary ?? this.summary,
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

class ProjectDocumentsController extends StateNotifier<ProjectDocumentsState> {
  final Ref _ref;
  final int projectId;

  ProjectDocumentsController(this._ref, this.projectId)
      : super(const ProjectDocumentsState());

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(projectRepositoryProvider);
      final data = await repo.listProjectDocuments(projectId);
      if (!mounted) return;
      state = state.copyWith(
        summary: data.summary,
        documents: data.documents,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> upload({
    required String filePath,
    String? filename,
    String? description,
  }) async {
    if (!mounted) return;
    state = state.copyWith(isUploading: true, error: null);
    try {
      final repo = _ref.read(projectRepositoryProvider);
      final created = await repo.uploadProjectDocument(
        projectId,
        filePath: filePath,
        filename: filename,
        description: description,
      );
      if (!mounted) return;
      state = state.copyWith(
        documents: [created, ...state.documents],
        summary: ProjectDocumentsSummary(
          count: state.summary.count + 1,
          canUpload: state.summary.canUpload,
          canDelete: state.summary.canDelete,
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

  Future<void> delete(int documentId) async {
    if (!mounted) return;
    state = state.copyWith(error: null);
    try {
      final repo = _ref.read(projectRepositoryProvider);
      await repo.deleteProjectDocument(projectId, documentId);
      if (!mounted) return;
      final remaining = state.documents
          .where((d) => d.id != documentId)
          .toList();
      state = state.copyWith(
        documents: remaining,
        summary: ProjectDocumentsSummary(
          count: remaining.length,
          canUpload: state.summary.canUpload,
          canDelete: state.summary.canDelete,
        ),
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }
}

/// Project document list for a single [projectId].
final projectDocumentsProvider = StateNotifierProvider.autoDispose
    .family<ProjectDocumentsController, ProjectDocumentsState, int>(
  (ref, projectId) => ProjectDocumentsController(ref, projectId),
);
