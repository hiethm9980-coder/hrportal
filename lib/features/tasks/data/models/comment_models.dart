/// Models for the Comments tab on the task detail screen.
///
/// Endpoints:
///   GET    /api/v1/tasks/{id}/comments
///   POST   /api/v1/tasks/{id}/comments
///   DELETE /api/v1/tasks/{id}/comments/{commentId}
///   GET    /api/v1/tasks/{id}/mention-candidates
///
/// The backend returns comments newest-first (`created_at DESC`). The UI
/// wants WhatsApp ordering (oldest first, newest at the bottom) — we reverse
/// the list when grouping by date in the widget layer.
///
/// Mention encoding inside [Comment.body] is `@[emp:ID|NAME]`. The server
/// also gives us a pre-rendered [Comment.bodyPlain] as a convenience for
/// quick previews, but the rich UI parses the raw body so it can render
/// chips for each mention.
library;

/// Lightweight author embedded in every comment.
class CommentAuthor {
  final int id;
  final String? code;
  final String name;
  final String? avatarUrl;

  const CommentAuthor({
    required this.id,
    required this.name,
    this.code,
    this.avatarUrl,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) {
    return CommentAuthor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      avatarUrl:
          json['avatar']?.toString() ?? json['avatar_url']?.toString(),
    );
  }

  static CommentAuthor? tryFromJson(Object? raw) {
    if (raw is Map) {
      return CommentAuthor.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// One @mention extracted from a comment by the server. Used to (a) detect
/// known employees when building the rich text and (b) optionally open a
/// profile when the chip is tapped.
class CommentMention {
  final int employeeId;
  final String? code;
  final String name;

  const CommentMention({
    required this.employeeId,
    required this.name,
    this.code,
  });

  factory CommentMention.fromJson(Map<String, dynamic> json) {
    return CommentMention(
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString(),
      name: json['name']?.toString() ?? '',
    );
  }
}

/// A single comment row.
class Comment {
  final int id;
  final String body;          // raw, with @[emp:ID|NAME] tokens
  final String bodyPlain;     // human-readable fallback
  final CommentAuthor? author;
  final List<CommentMention> mentions;
  final DateTime? createdAt;
  final bool isEdited;
  final bool canDelete;

  const Comment({
    required this.id,
    required this.body,
    required this.bodyPlain,
    this.author,
    this.mentions = const [],
    this.createdAt,
    this.isEdited = false,
    this.canDelete = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final mentionsRaw = (json['mentions'] as List?) ?? const [];
    final mentions = mentionsRaw
        .whereType<Map>()
        .map((e) => CommentMention.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Comment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      body: json['body']?.toString() ?? '',
      bodyPlain: json['body_plain']?.toString() ?? json['body']?.toString() ?? '',
      author: CommentAuthor.tryFromJson(json['author']),
      mentions: mentions,
      createdAt: _parseDate(json['created_at']),
      isEdited: json['is_edited'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }
}

/// Top-level summary card for the tab.
class CommentsSummary {
  final int count;
  final bool canAdd;

  const CommentsSummary({
    this.count = 0,
    this.canAdd = false,
  });

  factory CommentsSummary.fromJson(Map<String, dynamic> json) {
    return CommentsSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      canAdd: json['can_add'] as bool? ?? false,
    );
  }
}

/// Complete payload returned by `GET /api/v1/tasks/{id}/comments`.
class CommentsData {
  final CommentsSummary summary;
  final List<Comment> comments; // server order: newest first

  const CommentsData({
    this.summary = const CommentsSummary(),
    this.comments = const [],
  });

  factory CommentsData.fromJson(Map<String, dynamic> json) {
    final raw = (json['comments'] as List?) ?? const [];
    final list = raw
        .whereType<Map>()
        .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return CommentsData(
      summary: json['summary'] is Map
          ? CommentsSummary.fromJson(
              Map<String, dynamic>.from(json['summary']))
          : const CommentsSummary(),
      comments: list,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Mention candidates — used by the @ popup in the comment composer.
// ═══════════════════════════════════════════════════════════════════

/// Role badge attached to each mention candidate. The label/color are server
/// driven so the UI never has to map role codes to strings or hex.
class MentionRole {
  final String code;   // PROJECT_MANAGER | TASK_ASSIGNEE | TASK_MEMBER
  final String label;
  final String color;  // hex

  const MentionRole({
    required this.code,
    required this.label,
    required this.color,
  });

  factory MentionRole.fromJson(Map<String, dynamic> json) {
    return MentionRole(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9CA3AF',
    );
  }

  static MentionRole? tryFromJson(Object? raw) {
    if (raw is Map) {
      return MentionRole.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// One row in the @-popup. The server already pre-renders [mentionToken]
/// (the exact string we drop into the comment body) so we never assemble
/// `@[emp:ID|NAME]` ourselves.
class MentionCandidate {
  final int id;
  final String? code;
  final String name;
  final String? photoUrl;
  final MentionRole? role;
  final bool isPriority;
  final String mentionToken;

  const MentionCandidate({
    required this.id,
    required this.name,
    required this.mentionToken,
    this.code,
    this.photoUrl,
    this.role,
    this.isPriority = false,
  });

  factory MentionCandidate.fromJson(Map<String, dynamic> json) {
    return MentionCandidate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      role: MentionRole.tryFromJson(json['role']),
      isPriority: json['is_priority'] as bool? ?? false,
      mentionToken: json['mention_token']?.toString() ?? '',
    );
  }
}

/// Top-level response of `GET /api/v1/tasks/{id}/mention-candidates`.
class MentionCandidatesData {
  final List<MentionCandidate> items;

  const MentionCandidatesData({this.items = const []});

  factory MentionCandidatesData.fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List?) ?? const [];
    return MentionCandidatesData(
      items: raw
          .whereType<Map>()
          .map((e) => MentionCandidate.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
