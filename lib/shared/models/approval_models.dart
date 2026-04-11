import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════════
// ApprovalChainItem — one row of `approval_chain` (the *template*).
//
// Describes an approval level as defined by HR on the leave/request type.
// Use this to render levels that may not yet have a corresponding entry
// in `approval_history` (e.g. inactive levels because of
// `min_consecutive_days` on a leave shorter than the threshold).
// ═══════════════════════════════════════════════════════════════════

class ApprovalChainItem extends Equatable {
  final int level;
  final String approverType; // user|role|direct_manager|...
  final String label; // localized, server-resolved
  final int? minConsecutiveDays;
  final String? activationRuleText;

  const ApprovalChainItem({
    required this.level,
    required this.approverType,
    required this.label,
    this.minConsecutiveDays,
    this.activationRuleText,
  });

  factory ApprovalChainItem.fromJson(Map<String, dynamic> json) {
    return ApprovalChainItem(
      level: (json['level'] as int?) ?? 1,
      approverType: (json['approver_type'] as String?) ?? '',
      label: (json['label'] as String?) ??
          (json['label_ar'] as String?) ??
          (json['label_en'] as String?) ??
          '',
      minConsecutiveDays: json['min_consecutive_days'] as int?,
      activationRuleText: json['activation_rule_text'] as String?,
    );
  }

  @override
  List<Object?> get props => [level, approverType, label];
}

// ═══════════════════════════════════════════════════════════════════
// ApprovalHistoryItem — one row of `approval_history` returned by the API.
//
// This is the *live* state of a level (who decided, when, with what notes).
// `is_current=true` + `decision='pending'` → this approver is the one
// currently blocking the request.
// ═══════════════════════════════════════════════════════════════════

class ApprovalHistoryItem extends Equatable {
  final int level;
  final String approverType; // user|role|direct_manager|...
  /// Snapshot label as captured the moment the chain was built. This is the
  /// preferred display label per backend guidance — fall back to
  /// `labelAr`/`labelEn` only if `label` is missing (older requests).
  final String label;
  final String? labelAr;
  final String? labelEn;
  final int? approverId;
  final String? approverName;
  final String decision; // pending|approved|rejected
  final String? decisionText;
  final String? decidedAt;
  final String? notes;
  final bool isCurrent;
  /// Real user who pressed the button (may differ from the expected `approver`
  /// — for example when the company manager bypasses an intermediate approver).
  final int? decidedById;
  final String? decidedByName;
  /// Leaves only — `min_consecutive_days` snapshot captured at the time the
  /// chain was built. Always `null` for employee (other) requests.
  final int? minConsecutiveDaysSnapshot;
  /// Leaves only — human-readable activation rule snapshot. Always `null`
  /// for employee (other) requests.
  final String? activationRuleText;

  const ApprovalHistoryItem({
    required this.level,
    required this.approverType,
    this.label = '',
    this.labelAr,
    this.labelEn,
    this.approverId,
    this.approverName,
    required this.decision,
    this.decisionText,
    this.decidedAt,
    this.notes,
    this.isCurrent = false,
    this.decidedById,
    this.decidedByName,
    this.minConsecutiveDaysSnapshot,
    this.activationRuleText,
  });

  factory ApprovalHistoryItem.fromJson(Map<String, dynamic> json) {
    final approver = json['approver'];
    final decidedBy = json['decided_by'];
    return ApprovalHistoryItem(
      level: (json['level'] as int?) ?? 1,
      approverType: (json['approver_type'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      labelAr: json['label_ar'] as String?,
      labelEn: json['label_en'] as String?,
      approverId:
          approver is Map<String, dynamic> ? approver['id'] as int? : null,
      approverName: approver is Map<String, dynamic>
          ? approver['name'] as String?
          : null,
      decision: (json['decision'] as String?) ?? 'pending',
      decisionText: json['decision_text'] as String?,
      decidedAt: json['decided_at'] as String?,
      notes: json['notes'] as String?,
      isCurrent: (json['is_current'] as bool?) ?? false,
      decidedById:
          decidedBy is Map<String, dynamic> ? decidedBy['id'] as int? : null,
      decidedByName: decidedBy is Map<String, dynamic>
          ? decidedBy['name'] as String?
          : null,
      minConsecutiveDaysSnapshot:
          (json['min_consecutive_days_snapshot'] as num?)?.toInt(),
      activationRuleText: json['activation_rule_text'] as String?,
    );
  }

  /// Resolve a display label, preferring the snapshot `label`.
  String resolvedLabel(bool isAr) {
    if (label.isNotEmpty) return label;
    if (isAr) return labelAr ?? labelEn ?? '';
    return labelEn ?? labelAr ?? '';
  }

  @override
  List<Object?> get props => [level, decision, isCurrent, approverId];
}

// ═══════════════════════════════════════════════════════════════════
// Helpers shared by features that render approval timelines.
// ═══════════════════════════════════════════════════════════════════

/// Picks the current pending approver from a history list, if any.
ApprovalHistoryItem? currentApproverFromHistory(
    List<ApprovalHistoryItem> history) {
  for (final h in history) {
    if (h.isCurrent && h.decision == 'pending') return h;
  }
  return null;
}

/// Display name for the current approver. Prefers the real user name,
/// falls back to the role label snapshot.
String currentApproverDisplayFromHistory(
  List<ApprovalHistoryItem> history,
  bool isAr,
) {
  final h = currentApproverFromHistory(history);
  if (h == null) return '';
  if (h.approverName != null && h.approverName!.isNotEmpty) {
    return h.approverName!;
  }
  return h.resolvedLabel(isAr);
}
