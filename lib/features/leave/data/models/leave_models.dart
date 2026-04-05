import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';

// ═══════════════════════════════════════════════════════════════════
// LeaveType
// ═══════════════════════════════════════════════════════════════════

class LeaveType extends Equatable {
  final int? id;
  final String? code;
  final String name;
  final String? nameEn;
  final String? color;
  final bool isPaid;
  final bool requiresAttachment;
  final bool allowsHalfDay;
  final int? maxConsecutiveDays;

  const LeaveType({
    required this.id,
    this.code,
    required this.name,
    this.nameEn,
    this.color,
    required this.isPaid,
    this.requiresAttachment = false,
    this.allowsHalfDay = false,
    this.maxConsecutiveDays,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id'] ?? 0,
      code: json['code'] as String?,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      color: json['color'] as String?,
      isPaid: json['is_paid'] as bool? ?? true,
      requiresAttachment: json['requires_attachment'] as bool? ?? false,
      allowsHalfDay: json['allows_half_day'] as bool? ?? false,
      maxConsecutiveDays: json['max_consecutive_days'] as int?,
    );
  }

  @override
  List<Object?> get props => [id];
}

// ═══════════════════════════════════════════════════════════════════
// LeaveBalance
// ═══════════════════════════════════════════════════════════════════

class LeaveBalance extends Equatable {
  final int? id;
  final int? leaveYear;
  final LeaveType? leaveType;
  final double initialBalance;
  final double earned;
  final double used;
  final double pending;
  final double adjusted;
  final double carriedOver;
  final double totalEntitlement;
  final double available;

  const LeaveBalance({
    required this.id,
    required this.leaveYear,
    this.leaveType,
    required this.initialBalance,
    required this.earned,
    required this.used,
    required this.pending,
    required this.adjusted,
    required this.carriedOver,
    required this.totalEntitlement,
    required this.available,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      id: json['id'] ?? 0,
      leaveYear: json['leave_year'] ?? json['year'] ?? 0,
      leaveType: json['leave_type'] != null
          ? LeaveType.fromJson(json['leave_type'] as Map<String, dynamic>)
          : null,
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0,
      earned: (json['earned'] as num?)?.toDouble() ?? 0,
      used: (json['used'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0,
      adjusted: (json['adjusted'] as num?)?.toDouble() ?? 0,
      carriedOver: (json['carried_over'] as num?)?.toDouble() ?? 0,
      totalEntitlement: (json['total_entitlement'] as num?)?.toDouble() ?? 0,
      available: (json['available'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, leaveYear];
}

// ═══════════════════════════════════════════════════════════════════
// LeaveBalancesData (from GET /leave-balances)
// ═══════════════════════════════════════════════════════════════════

class LeaveBalancesData {
  final List<LeaveBalance> balances;
  final int year;

  const LeaveBalancesData({
    required this.balances,
    required this.year,
  });

  factory LeaveBalancesData.fromJson(Map<String, dynamic> json) {
    return LeaveBalancesData(
      balances: (json['balances'] as List)
          .map((e) => LeaveBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      year: json['year'] as int? ?? DateTime.now().year,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Approver
// ═══════════════════════════════════════════════════════════════════

class LeaveApprover extends Equatable {
  final int id;
  final String name;
  final int approvalLevel;
  final String decision;

  const LeaveApprover({
    required this.id,
    required this.name,
    required this.approvalLevel,
    required this.decision,
  });

  factory LeaveApprover.fromJson(Map<String, dynamic> json) {
    return LeaveApprover(
      id: json['id'] as int,
      name: json['name'] as String,
      approvalLevel: json['approval_level'] as int? ?? 1,
      decision: json['decision'] as String? ?? 'pending',
    );
  }

  @override
  List<Object?> get props => [id];
}

// ═══════════════════════════════════════════════════════════════════
// LeaveRequest
// ═══════════════════════════════════════════════════════════════════

class LeaveRequest extends Equatable {
  final int? id;
  final String? requestNumber;
  final LeaveType? leaveType;
  final String startDate;
  final String endDate;
  final double totalDays;
  final String status; // draft|pending|approved|rejected|cancelled
  final LeaveApprover? approver;
  final String? reason;
  final String? rejectionReason;
  final String? createdAt;

  const LeaveRequest({
    required this.id,
    this.requestNumber,
    this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.status,
    this.approver,
    this.reason,
    this.rejectionReason,
    this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] ?? 0,
      requestNumber: json['request_number'] as String?,
      leaveType: json['leave_type'] != null
          ? LeaveType.fromJson(json['leave_type'] as Map<String, dynamic>)
          : null,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      totalDays: (json['total_days'] as num).toDouble(),
      status: json['status'] as String,
      approver: json['approver'] != null
          ? LeaveApprover.fromJson(json['approver'] as Map<String, dynamic>)
          : null,
      reason: json['reason'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isPending => status == 'pending';
  bool get canDelete => isDraft || isPending;
  bool get canSubmit => isDraft;

  @override
  List<Object?> get props => [id];
}

// ═══════════════════════════════════════════════════════════════════
// LeaveSummary (from GET /leave-requests/summary)
// ═══════════════════════════════════════════════════════════════════

class LeaveSummary extends Equatable {
  final int total;
  final int draft;
  final int pending;
  final int approved;
  final int rejected;
  final int cancelled;

  const LeaveSummary({
    required this.total,
    required this.draft,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.cancelled,
  });

  factory LeaveSummary.fromJson(Map<String, dynamic> json) {
    return LeaveSummary(
      total: json['total'] as int,
      draft: json['draft'] as int,
      pending: json['pending'] as int,
      approved: json['approved'] as int,
      rejected: json['rejected'] as int,
      cancelled: json['cancelled'] as int,
    );
  }

  @override
  List<Object?> get props => [total, draft, pending, approved, rejected, cancelled];
}

// ═══════════════════════════════════════════════════════════════════
// LeavesData (from GET /leave-requests)
// ═══════════════════════════════════════════════════════════════════

class LeavesData {
  final List<LeaveRequest> requests;
  final Pagination pagination;

  const LeavesData({
    required this.requests,
    required this.pagination,
  });

  factory LeavesData.fromJson(Map<String, dynamic> json) {
    return LeavesData(
      requests: (json['leave_requests'] as List)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}
