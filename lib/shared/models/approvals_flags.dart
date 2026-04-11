import 'package:equatable/equatable.dart';

/// Approval feature flags returned by login/me.
///
/// Tells the app whether the current user has any pending approvals to act on
/// (and how many), so the UI can show or hide the Approvals tab and badges.
class ApprovalsFlags extends Equatable {
  final bool hasLeaveApprovals;
  final bool hasOtherApprovals;
  final int pendingLeavesCount;
  final int pendingRequestsCount;

  const ApprovalsFlags({
    this.hasLeaveApprovals = false,
    this.hasOtherApprovals = false,
    this.pendingLeavesCount = 0,
    this.pendingRequestsCount = 0,
  });

  bool get hasAny => hasLeaveApprovals || hasOtherApprovals;

  factory ApprovalsFlags.fromJson(Map<String, dynamic> json) {
    return ApprovalsFlags(
      hasLeaveApprovals: (json['has_leave_approvals'] as bool?) ?? false,
      hasOtherApprovals: (json['has_other_approvals'] as bool?) ?? false,
      pendingLeavesCount:
          (json['pending_leaves_count'] as num?)?.toInt() ?? 0,
      pendingRequestsCount:
          (json['pending_requests_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'has_leave_approvals': hasLeaveApprovals,
        'has_other_approvals': hasOtherApprovals,
        'pending_leaves_count': pendingLeavesCount,
        'pending_requests_count': pendingRequestsCount,
      };

  @override
  List<Object?> get props => [
        hasLeaveApprovals,
        hasOtherApprovals,
        pendingLeavesCount,
        pendingRequestsCount,
      ];
}

/// One company a manager can switch into when filtering approvals.
class ManagedCompany extends Equatable {
  final int id;
  final String name;
  final int pendingLeavesCount;
  final int pendingRequestsCount;

  const ManagedCompany({
    required this.id,
    required this.name,
    this.pendingLeavesCount = 0,
    this.pendingRequestsCount = 0,
  });

  factory ManagedCompany.fromJson(Map<String, dynamic> json) {
    return ManagedCompany(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      pendingLeavesCount:
          (json['pending_leaves_count'] as num?)?.toInt() ?? 0,
      pendingRequestsCount:
          (json['pending_requests_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pending_leaves_count': pendingLeavesCount,
        'pending_requests_count': pendingRequestsCount,
      };

  @override
  List<Object?> get props => [id, name];
}
