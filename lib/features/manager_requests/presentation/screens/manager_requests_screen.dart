import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/utils/app_funs.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../data/models/manager_request_models.dart';
import '../../data/models/manager_leave_models.dart';
import '../providers/manager_request_providers.dart';
import '../providers/manager_leave_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// Manager Approvals Screen (TabBar: Leaves | Requests)
// ═══════════════════════════════════════════════════════════════════

class ManagerRequestsScreen extends ConsumerStatefulWidget {
  const ManagerRequestsScreen({super.key});

  @override
  ConsumerState<ManagerRequestsScreen> createState() =>
      _ManagerRequestsScreenState();
}

class _ManagerRequestsScreenState extends ConsumerState<ManagerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.read(managerLeavesListProvider.notifier).refresh();
    ref.read(managerRequestsListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Approvals'.tr(context),
            onRefresh: _refresh,
          ),

          // ── TabBar ──
          Container(
            color: context.appColors.bgCard,
            child: TabBar(
              controller: _tabController,
              labelStyle: TextStyle(fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: context.appColors.textMuted,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(0),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.primary,
                    width: 3,
                  ),
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              dividerHeight: 0.5,
              dividerColor: context.appColors.gray200,
              splashBorderRadius: BorderRadius.circular(0),
              tabs: [
                Tab(text: 'Leaves'.tr(context)),
                Tab(text: 'Requests'.tr(context)),
              ],
            ),
          ),

          // ── TabBarView ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ManagerLeavesTab(),
                _ManagerRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 1: Manager Leaves
// ═══════════════════════════════════════════════════════════════════

class _ManagerLeavesTab extends ConsumerWidget {
  const _ManagerLeavesTab();

  static const _statusFilters = [
    (null, 'All'),
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(managerLeavesListProvider.notifier);

    return Column(
      children: [
        // ── Status Filter Tabs ──
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isActive = controller.statusFilter == filter.$1;
                return GestureDetector(
                  onTap: () => controller.setStatusFilter(filter.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryMid
                          : context.appColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primaryMid
                            : context.appColors.gray200,
                      ),
                    ),
                    child: Text(
                      filter.$2.tr(context),
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : context.appColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── List ──
        Expanded(
          child: PaginatedListView<ManagerLeave>(
            state: ref.watch(managerLeavesListProvider),
            onRefresh: () => controller.refresh(),
            onLoadMore: () => controller.loadMore(),
            emptyIcon: Icons.event_available,
            emptyTitle: 'No leave requests'.tr(context),
            emptySubtitle:
                'Employee leave requests will appear here'.tr(context),
            itemBuilder: (context, leave) =>
                _ManagerLeaveTile(leave: leave),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Manager Leave Tile (matches leave card design)
// ═══════════════════════════════════════════════════════════════════

class _ManagerLeaveTile extends StatelessWidget {
  final ManagerLeave leave;
  const _ManagerLeaveTile({required this.leave});

  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
        return 'pending';
      default:
        return 'info';
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatLeaveDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return AppFuns.formatDate(d);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatCreatedDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return AppFuns.formatDate(d);
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormatted = _formatLeaveDate(leave.startDate);
    final endFormatted = _formatLeaveDate(leave.endDate);
    final days = leave.totalDays;
    final daysLabel = days == days.truncateToDouble()
        ? '${days.toInt()} ${'d'.tr(context)}'
        : '${days.toStringAsFixed(1)} ${'d'.tr(context)}';

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // ── Row 1: Days | Leave type (centered) | Status ──
            Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    leave.leaveType?.name ?? '',
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      daysLabel,
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                    StatusBadge(
                      text: _statusLabel(leave.status).tr(context),
                      type: _statusType(leave.status),
                      dot: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: From date — To date ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          startFormatted,
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From'.tr(context),
                        style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 10,
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '—',
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 16,
                    color: context.appColors.textMuted,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          endFormatted,
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'To'.tr(context),
                        style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 10,
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Row 3: Employee name (start) | Created at (end) ──
            const SizedBox(height: 8),
            Row(
              children: [
                if (leave.employee != null)
                  Expanded(
                    child: Text(
                      leave.employee!.name,
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 10,
                        color: context.appColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  _formatCreatedDate(leave.createdAt),
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 10,
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.appColors.bgCard,
      builder: (_) => _ManagerLeaveDetailSheet(leave: leave),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Manager Leave Detail Bottom Sheet (with approve/reject)
// ═══════════════════════════════════════════════════════════════════

class _ManagerLeaveDetailSheet extends ConsumerStatefulWidget {
  final ManagerLeave leave;
  const _ManagerLeaveDetailSheet({required this.leave});

  @override
  ConsumerState<_ManagerLeaveDetailSheet> createState() =>
      _ManagerLeaveDetailSheetState();
}

class _ManagerLeaveDetailSheetState
    extends ConsumerState<_ManagerLeaveDetailSheet> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
        return 'pending';
      default:
        return 'info';
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _dayPartLabel(String dayPart) {
    switch (dayPart.toLowerCase()) {
      case 'full':
        return 'Full day';
      case 'first_half':
        return 'First half';
      case 'second_half':
        return 'Second half';
      default:
        return dayPart;
    }
  }

  bool get _canDecide => widget.leave.status == 'pending';

  void _handleDecide(String status) {
    final notes = _notesController.text.trim();

    // Reject requires notes
    if (status == 'rejected' && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejection notes are required'.tr(context)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    ref.read(decideLeaveProvider.notifier).decide(
          leaveId: widget.leave.id,
          status: status,
          rejectionReason: notes.isNotEmpty ? notes : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final decideState = ref.watch(decideLeaveProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    ref.listen<DecideLeaveState>(decideLeaveProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess != true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Decision submitted successfully'.tr(context)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      if (next.error != null && prev?.error != next.error) {
        GlobalErrorHandler.show(context, next.error!);
      }
    });

    final r = widget.leave;

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title & Status ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: 10, top: 2),
                    child: Icon(Icons.close,
                        size: 22, color: context.appColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.leaveType?.name ?? 'Leave'.tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  text: _statusLabel(r.status).tr(context),
                  type: _statusType(r.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info Rows ──
            if (r.employee != null)
              _InfoRow(
                icon: '👤',
                label: 'Employee'.tr(context),
                value: '${r.employee!.name} (${r.employee!.code})',
              ),
            _InfoRow(
              icon: '📅',
              label: 'From'.tr(context),
              value: r.startDate,
            ),
            _InfoRow(
              icon: '📅',
              label: 'To'.tr(context),
              value: r.endDate,
            ),
            _InfoRow(
              icon: '⏱',
              label: 'Total days'.tr(context),
              value:
                  '${r.totalDays.toStringAsFixed(1)} ${'day'.tr(context)}',
            ),
            _InfoRow(
              icon: '🕐',
              label: 'Day part'.tr(context),
              value: _dayPartLabel(r.dayPart).tr(context),
            ),
            _InfoRow(
              icon: '📆',
              label: 'Created at'.tr(context),
              value: AppFuns.formatApiDateTime(r.createdAt, isAr: isAr),
            ),
            if (r.reason != null && r.reason!.isNotEmpty)
              _InfoRow(
                icon: '📝',
                label: 'Reason'.tr(context),
                value: r.reason!,
                multiLine: true,
              ),
            if (r.rejectionReason != null && r.rejectionReason!.isNotEmpty)
              _InfoRow(
                icon: '❌',
                label: 'Rejection reason'.tr(context),
                value: r.rejectionReason!,
                multiLine: true,
              ),
            if (r.approvedAt != null)
              _InfoRow(
                icon: '✅',
                label: 'Approved at'.tr(context),
                value: AppFuns.formatApiDateTime(r.approvedAt!, isAr: isAr),
              ),

            // ── Decision Section ──
            if (_canDecide) ...[
              const SizedBox(height: 16),
              Divider(color: context.appColors.gray200),
              const SizedBox(height: 12),

              // ── Rejection reason Input ──
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'Rejection reason'.tr(context),
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                enabled: !decideState.isLoading,
                style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add notes (required for rejection)'.tr(context),
                  hintStyle: TextStyle(fontFamily: 'Cairo',
                      fontSize: 12, color: context.appColors.textMuted),
                  errorText:
                      decideState.fieldError('rejection_reason'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Action Buttons ──
              if (decideState.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Row(
                  children: [
                    // ── Reject Button ──
                    Expanded(
                      child: AppOutlineButton(
                        text: 'Reject'.tr(context),
                        color: AppColors.error,
                        small: true,
                        onTap: () => _handleDecide('rejected'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ── Approve Button ──
                    Expanded(
                      child: TealButton(
                        text: 'Approve'.tr(context),
                        icon: '✓',
                        small: true,
                        onTap: () => _handleDecide('approved'),
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 2: Manager Requests (existing)
// ═══════════════════════════════════════════════════════════════════

class _ManagerRequestsTab extends ConsumerWidget {
  const _ManagerRequestsTab();

  static const _statusFilters = [
    (null, 'All'),
    ('pending', 'Pending'),
    ('processing', 'Processing'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(managerRequestsListProvider.notifier);

    return Column(
      children: [
        // ── Status Filter Tabs ──
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              shrinkWrap: true,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isActive = controller.statusFilter == filter.$1;
                return GestureDetector(
                  onTap: () => controller.setStatusFilter(filter.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryMid
                          : context.appColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primaryMid
                            : context.appColors.gray200,
                      ),
                    ),
                    child: Text(
                      filter.$2.tr(context),
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : context.appColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── List ──
        Expanded(
          child: PaginatedListView<ManagerRequest>(
            state: ref.watch(managerRequestsListProvider),
            onRefresh: () => controller.refresh(),
            onLoadMore: () => controller.loadMore(),
            emptyIcon: Icons.assignment_turned_in,
            emptyTitle: 'No pending requests'.tr(context),
            emptySubtitle:
                'Employee requests will appear here'.tr(context),
            itemBuilder: (context, request) =>
                _ManagerRequestTile(request: request),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Manager Request Tile
// ═══════════════════════════════════════════════════════════════════

class _ManagerRequestTile extends StatelessWidget {
  final ManagerRequest request;
  const _ManagerRequestTile({required this.request});

  String _statusType(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
      case 'processing':
        return 'pending';
      case 'cancelled':
        return 'navy';
      default:
        return 'info';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'salary_certificate':
        return 'Salary certificate';
      case 'experience_letter':
        return 'Experience letter';
      case 'vacation_settlement':
        return 'Vacation settlement';
      case 'loan_request':
        return 'Loan request';
      case 'expense_claim':
        return 'Expense claim';
      case 'training_request':
        return 'Training request';
      case 'other':
        return 'Other';
      default:
        return type ?? 'Request';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Subject + Status ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    request.subject ??
                        _typeLabel(request.requestType).tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  text: _statusLabel(request.status).tr(context),
                  type: _statusType(request.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Row 2: Employee + Type + Date ──
            Row(
              children: [
                if (request.employee != null) ...[
                  Icon(Icons.person_outline,
                      size: 14, color: context.appColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    request.employee!.name,
                    style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 11, color: context.appColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  _typeLabel(request.requestType).tr(context),
                  style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 11, color: context.appColors.textMuted),
                ),
                const Spacer(),
                Text(
                  request.createdAt.length >= 10
                      ? request.createdAt.substring(0, 10)
                      : request.createdAt,
                  style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 11, color: context.appColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.appColors.bgCard,
      builder: (_) => _ManagerRequestDetailSheet(request: request),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Manager Request Detail Bottom Sheet (with approve/reject)
// ═══════════════════════════════════════════════════════════════════

class _ManagerRequestDetailSheet extends ConsumerStatefulWidget {
  final ManagerRequest request;
  const _ManagerRequestDetailSheet({required this.request});

  @override
  ConsumerState<_ManagerRequestDetailSheet> createState() =>
      _ManagerRequestDetailSheetState();
}

class _ManagerRequestDetailSheetState
    extends ConsumerState<_ManagerRequestDetailSheet> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _statusType(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
      case 'processing':
        return 'pending';
      default:
        return 'info';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'salary_certificate':
        return 'Salary certificate';
      case 'experience_letter':
        return 'Experience letter';
      case 'vacation_settlement':
        return 'Vacation settlement';
      case 'loan_request':
        return 'Loan request';
      case 'expense_claim':
        return 'Expense claim';
      case 'training_request':
        return 'Training request';
      case 'other':
        return 'Other';
      default:
        return type ?? 'Request';
    }
  }

  bool get _canDecide {
    final s = widget.request.status;
    return s == 'pending' || s == 'processing';
  }

  void _handleDecide(String status) {
    final notes = _notesController.text.trim();

    if (status == 'rejected' && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejection notes are required'.tr(context)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    ref.read(decideRequestProvider.notifier).decide(
          requestId: widget.request.id,
          status: status,
          responseNotes: notes.isNotEmpty ? notes : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final decideState = ref.watch(decideRequestProvider);

    ref.listen<DecideRequestState>(decideRequestProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess != true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Decision submitted successfully'.tr(context)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      if (next.error != null && prev?.error != next.error) {
        GlobalErrorHandler.show(context, next.error!);
      }
    });

    final r = widget.request;

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title & Status ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: 10, top: 2),
                    child: Icon(Icons.close,
                        size: 22, color: context.appColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.subject ?? _typeLabel(r.requestType).tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  text: _statusLabel(r.status).tr(context),
                  type: _statusType(r.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info Rows ──
            if (r.employee != null)
              _InfoRow(
                icon: '👤',
                label: 'Employee'.tr(context),
                value: '${r.employee!.name} (${r.employee!.code})',
              ),
            _InfoRow(
              icon: '📋',
              label: 'Type'.tr(context),
              value: _typeLabel(r.requestType).tr(context),
            ),
            _InfoRow(
              icon: '📅',
              label: 'Created at'.tr(context),
              value: r.createdAt.length >= 10
                  ? r.createdAt.substring(0, 10)
                  : r.createdAt,
            ),
            if (r.description != null && r.description!.isNotEmpty)
              _InfoRow(
                icon: '📝',
                label: 'Details'.tr(context),
                value: r.description!,
                multiLine: true,
              ),
            if (r.responseNotes != null && r.responseNotes!.isNotEmpty)
              _InfoRow(
                icon: '💬',
                label: 'Response notes'.tr(context),
                value: r.responseNotes!,
                multiLine: true,
              ),
            if (r.respondedAt != null)
              _InfoRow(
                icon: '⏰',
                label: 'Responded at'.tr(context),
                value: r.respondedAt!.length >= 10
                    ? r.respondedAt!.substring(0, 10)
                    : r.respondedAt!,
              ),

            // ── Decision Section ──
            if (_canDecide) ...[
              const SizedBox(height: 16),
              Divider(color: context.appColors.gray200),
              const SizedBox(height: 12),

              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'Response notes'.tr(context),
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                enabled: !decideState.isLoading,
                style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add notes (required for rejection)'.tr(context),
                  hintStyle: TextStyle(fontFamily: 'Cairo',
                      fontSize: 12, color: context.appColors.textMuted),
                  errorText: decideState.fieldError('response_notes'),
                ),
              ),
              const SizedBox(height: 16),

              if (decideState.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: AppOutlineButton(
                        text: 'Reject'.tr(context),
                        color: AppColors.error,
                        small: true,
                        onTap: () => _handleDecide('rejected'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TealButton(
                        text: 'Approve'.tr(context),
                        icon: '✓',
                        small: true,
                        onTap: () => _handleDecide('approved'),
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Info Row Widget (shared)
// ═══════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool multiLine;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: multiLine ? 10 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
