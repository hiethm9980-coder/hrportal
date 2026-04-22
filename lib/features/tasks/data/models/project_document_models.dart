import 'attachment_models.dart';

/// Models for `GET /api/v1/projects/{id}/documents` (and related mutations).
class ProjectDocumentsSummary {
  final int count;
  final bool canUpload;
  final bool canDelete;

  const ProjectDocumentsSummary({
    this.count = 0,
    this.canUpload = false,
    this.canDelete = false,
  });

  factory ProjectDocumentsSummary.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentsSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      canUpload: json['can_upload'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }
}

class ProjectDocumentItem {
  final int id;
  final String name;
  final String title;
  final String? fileName;
  final String extension;
  final String? mimeType;
  final int? sizeBytes;
  final String sizeLabel;
  final String? description;
  final String? version;
  final bool? isLatest;
  final int? taskId;
  final DateTime? createdAt;
  final String? downloadUrl;
  final AttachmentUploader? uploader;
  final AttachmentUploaderRole? uploaderRole;
  final bool canDelete;

  const ProjectDocumentItem({
    required this.id,
    this.name = '',
    this.title = '',
    this.fileName,
    this.extension = '',
    this.mimeType,
    this.sizeBytes,
    this.sizeLabel = '',
    this.description,
    this.version,
    this.isLatest,
    this.taskId,
    this.createdAt,
    this.downloadUrl,
    this.uploader,
    this.uploaderRole,
    this.canDelete = false,
  });

  String get displayName {
    if (name.trim().isNotEmpty) return name;
    if (title.trim().isNotEmpty) return title;
    return '—';
  }

  factory ProjectDocumentItem.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      extension: json['extension']?.toString() ?? '',
      mimeType: json['mime_type']?.toString(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      sizeLabel: json['size_label']?.toString() ?? '—',
      description: json['description']?.toString(),
      version: json['version']?.toString(),
      isLatest: json['is_latest'] as bool?,
      taskId: (json['task_id'] as num?)?.toInt(),
      createdAt: _parseDate(json['created_at']),
      downloadUrl: json['download_url']?.toString(),
      uploader: AttachmentUploader.tryFromJson(json['uploader']),
      uploaderRole: AttachmentUploaderRole.tryFromJson(json['uploader_role']),
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }
}

class ProjectDocumentsData {
  final ProjectDocumentsSummary summary;
  final List<ProjectDocumentItem> documents;

  const ProjectDocumentsData({
    this.summary = const ProjectDocumentsSummary(),
    this.documents = const [],
  });

  factory ProjectDocumentsData.fromJson(Map<String, dynamic> json) {
    final raw = (json['documents'] as List?) ?? const [];
    final list = raw
        .whereType<Map>()
        .map((e) => ProjectDocumentItem.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
    return ProjectDocumentsData(
      summary: json['summary'] is Map
          ? ProjectDocumentsSummary.fromJson(
              Map<String, dynamic>.from(json['summary'] as Map),
            )
          : const ProjectDocumentsSummary(),
      documents: list,
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

/// Parses a POST/PUT `data` envelope: either the document or `{ "document": { ... } }`.
ProjectDocumentItem? projectDocumentFromMutationResponse(Object? json) {
  if (json is! Map) return null;
  final m = Map<String, dynamic>.from(json);
  final d = m['document'];
  if (d is Map) {
    return ProjectDocumentItem.fromJson(Map<String, dynamic>.from(d));
  }
  if (m.containsKey('id') || m.containsKey('name')) {
    return ProjectDocumentItem.fromJson(m);
  }
  return null;
}
