/// Models for the Attachments tab on the task detail screen.
///
/// Endpoints:
///   GET    /api/v1/tasks/{id}/attachments
///   POST   /api/v1/tasks/{id}/attachments           (multipart/form-data)
///   DELETE /api/v1/tasks/{id}/attachments/{attachmentId}
///
/// Notes:
/// - `created_at` comes as ISO-8601 with the server's UTC+03 offset. We parse
///   it as a real `DateTime` and call `.toLocal()` at display time so every
///   user sees times in *their* device timezone.
/// - `download_url` is now a RELATIVE path starting with `/` (server change).
///   Use `AppFuns.resolveDownloadUrl()` before handing it to the network
///   layer — never use it verbatim.
library;

/// Lightweight employee embedded as the uploader.
class AttachmentUploader {
  final int id;
  final String? code;
  final String name;

  const AttachmentUploader({
    required this.id,
    required this.name,
    this.code,
  });

  factory AttachmentUploader.fromJson(Map<String, dynamic> json) {
    return AttachmentUploader(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }

  static AttachmentUploader? tryFromJson(Object? raw) {
    if (raw is Map) {
      return AttachmentUploader.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// Role badge attached to each attachment's uploader. Server-driven so the
/// client never maps codes to strings/hex manually.
///
/// Possible codes: `PROJECT_MANAGER`, `TASK_ASSIGNEE`, `TASK_MEMBER`,
/// `NOT_MEMBER`.
class AttachmentUploaderRole {
  final String code;
  final String label;
  final String color; // hex

  const AttachmentUploaderRole({
    required this.code,
    required this.label,
    required this.color,
  });

  factory AttachmentUploaderRole.fromJson(Map<String, dynamic> json) {
    return AttachmentUploaderRole(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9CA3AF',
    );
  }

  static AttachmentUploaderRole? tryFromJson(Object? raw) {
    if (raw is Map) {
      return AttachmentUploaderRole.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// One attachment row returned by the server.
class TaskAttachment {
  final int id;
  final String name;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final String sizeLabel;
  final DateTime? createdAt;
  /// Relative path like `/storage/pm/attachments/.../xxx.pdf`. The UI must
  /// prefix the app's `baseUrl` via `AppFuns.resolveDownloadUrl` before
  /// opening / downloading.
  final String downloadUrl;
  final AttachmentUploader? uploader;
  final AttachmentUploaderRole? uploaderRole;
  final bool canDelete;

  const TaskAttachment({
    required this.id,
    required this.name,
    this.extension = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.sizeLabel = '',
    this.createdAt,
    this.downloadUrl = '',
    this.uploader,
    this.uploaderRole,
    this.canDelete = false,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      extension: json['extension']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sizeLabel: json['size_label']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      downloadUrl: json['download_url']?.toString() ?? '',
      uploader: AttachmentUploader.tryFromJson(json['uploader']),
      uploaderRole:
          AttachmentUploaderRole.tryFromJson(json['uploader_role']),
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }
}

/// Top-level summary for the tab.
class AttachmentsSummary {
  final int count;
  final bool canUpload;

  const AttachmentsSummary({
    this.count = 0,
    this.canUpload = false,
  });

  factory AttachmentsSummary.fromJson(Map<String, dynamic> json) {
    return AttachmentsSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      canUpload: json['can_upload'] as bool? ?? false,
    );
  }
}

/// Complete payload returned by `GET /api/v1/tasks/{id}/attachments`.
class AttachmentsData {
  final AttachmentsSummary summary;
  /// Server order: newest first. The UI reverses for date-grouped display
  /// (oldest at top, newest at bottom — WhatsApp style).
  final List<TaskAttachment> attachments;

  const AttachmentsData({
    this.summary = const AttachmentsSummary(),
    this.attachments = const [],
  });

  factory AttachmentsData.fromJson(Map<String, dynamic> json) {
    final raw = (json['attachments'] as List?) ?? const [];
    final list = raw
        .whereType<Map>()
        .map((e) => TaskAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return AttachmentsData(
      summary: json['summary'] is Map
          ? AttachmentsSummary.fromJson(
              Map<String, dynamic>.from(json['summary']))
          : const AttachmentsSummary(),
      attachments: list,
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
