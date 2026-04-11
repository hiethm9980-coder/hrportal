import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';
import '../../../leave/data/models/leave_models.dart';

/// Employee info embedded in a manager leave request.
class LeaveEmployee extends Equatable {
  final int id;
  final String name;
  final String code;
  final String? jobTitle;
  final String? photoUrl;
  final String? departmentName;

  const LeaveEmployee({
    required this.id,
    required this.name,
    required this.code,
    this.jobTitle,
    this.photoUrl,
    this.departmentName,
  });

  factory LeaveEmployee.fromJson(Map<String, dynamic> json) {
    final department = json['department'];
    return LeaveEmployee(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      jobTitle: json['job_title'] as String?,
      photoUrl: json['photo_url'] as String?,
      departmentName: department is Map<String, dynamic>
          ? department['name'] as String?
          : null,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Manager leave item (from GET /approvals/leaves).
class ManagerLeave extends Equatable {
  final int id;
  final String? requestNumber;
  final LeaveType? leaveType;
  final String startDate;
  final String endDate;
  final double totalDays;
  final String dayPart;
  final String? reason;
  final String status;
  final String? rejectionReason;
  final int? approvedBy;
  final String? approvedAt;
  final String createdAt;
  final String? updatedAt;
  final String? attachmentPath;
  final String? attachmentUrl;
  final LeaveEmployee? employee;
  final int? currentApprovalLevel;
  final int? totalLevels;
  final bool canDecide;
  final List<ApprovalChainItem> approvalChain;
  final List<ApprovalHistoryItem> approvalHistory;

  const ManagerLeave({
    required this.id,
    this.requestNumber,
    this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.dayPart,
    this.reason,
    required this.status,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    this.updatedAt,
    this.attachmentPath,
    this.attachmentUrl,
    this.employee,
    this.currentApprovalLevel,
    this.totalLevels,
    this.canDecide = false,
    this.approvalChain = const [],
    this.approvalHistory = const [],
  });

  bool get hasAttachment =>
      (attachmentUrl != null && attachmentUrl!.isNotEmpty) ||
      (attachmentPath != null && attachmentPath!.isNotEmpty);

  factory ManagerLeave.fromJson(Map<String, dynamic> json) {
    final employeeJson =
        (json['requester'] ?? json['employee']) as Map<String, dynamic>?;

    return ManagerLeave(
      id: json['id'] as int,
      requestNumber: json['request_number'] as String?,
      leaveType: json['leave_type'] != null
          ? LeaveType.fromJson(json['leave_type'] as Map<String, dynamic>)
          : null,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      totalDays: (json['total_days'] as num).toDouble(),
      dayPart: json['day_part'] as String,
      reason: json['reason'] as String?,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      approvedBy: json['approved_by'] as int?,
      approvedAt: json['approved_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String?,
      attachmentPath: json['attachment_path'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      employee: employeeJson != null
          ? LeaveEmployee.fromJson(employeeJson)
          : null,
      currentApprovalLevel: json['current_approval_level'] as int?,
      totalLevels: json['total_levels'] as int?,
      canDecide: json['can_decide'] as bool? ??
          ((json['status'] as String?)?.toLowerCase() == 'pending'),
      approvalChain: (json['approval_chain'] as List?)
              ?.map((e) => ApprovalChainItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      approvalHistory: (json['approval_history'] as List?)
              ?.map(
                  (e) => ApprovalHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Parsed data from GET /approvals/leaves.
class ManagerLeavesData {
  final List<ManagerLeave> leaves;
  final Pagination pagination;

  const ManagerLeavesData({
    required this.leaves,
    required this.pagination,
  });

  factory ManagerLeavesData.fromJson(Map<String, dynamic> json) {
    return ManagerLeavesData(
      leaves: (json['leaves'] as List)
          .map((e) => ManagerLeave.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}
