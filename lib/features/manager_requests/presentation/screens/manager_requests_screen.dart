import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/notification_route_handler.dart';
import '../../../../core/services/notifications_bus.dart';
import '../../../../core/utils/app_funs.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/approval_timeline.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/manager_request_models.dart';
import '../../data/models/manager_leave_models.dart';
import '../providers/manager_request_providers.dart';
import '../providers/manager_leave_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// Public helpers to show approval detail sheets from any screen
// ═══════════════════════════════════════════════════════════════════

/// Show manager leave approval detail bottomsheet.
void showManagerLeaveDetailSheet(BuildContext context, ManagerLeave leave) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.80,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: context.appColors.bgCard,
    builder: (_) => _ManagerLeaveDetailSheet(leave: leave),
  );
}

/// Show manager request approval detail bottomsheet.
void showManagerRequestDetailSheet(BuildContext context, ManagerRequest request) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.80,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: context.appColors.bgCard,
    builder: (_) => _ManagerRequestDetailSheet(request: request),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Manager Approvals Screen (TabBar: Leaves | Requests)
// ═══════════════════════════════════════════════════════════════════

class ManagerRequestsScreen extends ConsumerStatefulWidget {
  final String? openLeaveId;
  final String? openRequestId;
  const ManagerRequestsScreen({
    super.key,
    this.openLeaveId,
    this.openRequestId,
  });

  @override
  ConsumerState<ManagerRequestsScreen> createState() =>
      _ManagerRequestsScreenState();
}

class _ManagerRequestsScreenState extends ConsumerState<ManagerRequestsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _tabCount = 0;
  bool _showLeaves = false;
  bool _showRequests = false;
  bool _didAutoOpen = false;
  StreamSubscription<String>? _routeSub;

  @override
  void initState() {
    super.initState();
    // Fetch fresh data for both tabs + pending counts on first open.
    Future.microtask(() {
      _ensureTabController();
      _refreshAll();
    });

    // Auto-refresh when a relevant foreground notification arrives.
    _routeSub = NotificationsBus.routeStream.listen(_onNotificationRoute);
  }

  void _onNotificationRoute(String route) {
    final parsed = parseNotificationRoute(route);
    if (parsed == null) return;

    if (parsed.type == NotificationRouteType.approvalLeave && _showLeaves) {
      ref.read(managerLeavesListProvider.notifier).refresh();
      ref.read(managerLeavesListProvider.notifier).refreshPendingCount();
    }
    if (parsed.type == NotificationRouteType.approvalRequest && _showRequests) {
      ref.read(managerRequestsListProvider.notifier).refresh();
      ref.read(managerRequestsListProvider.notifier).refreshPendingCount();
    }
  }

  void _ensureTabController() {
    final auth = ref.read(authProvider);
    // Strict: tabs follow backend flags exactly. A tab is hidden the moment
    // its flag is false — no legacy "show by default" fallback.
    final showLeaves = auth.hasLeaveApprovals;
    final showRequests = auth.hasOtherApprovals;
    final count = (showLeaves ? 1 : 0) + (showRequests ? 1 : 0);
    // TabController requires length >= 1; we still create one to keep the
    // widget alive when both flags are false (the body shows an empty state).
    final effectiveCount = count == 0 ? 1 : count;

    if (_tabController == null || _tabCount != effectiveCount) {
      _tabController?.dispose();
      _tabController = TabController(length: effectiveCount, vsync: this);
      _tabCount = effectiveCount;
      // Refresh data & pending counts when switching between tabs.
      _tabController!.addListener(_onTabChanged);
    }
    _showLeaves = showLeaves;
    _showRequests = showRequests;
  }

  void _onTabChanged() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    _refreshCurrentTab();
  }

  /// Refresh only the currently visible tab + its pending count.
  void _refreshCurrentTab() {
    final index = _tabController?.index ?? 0;
    // When both tabs exist: 0 = leaves, 1 = requests.
    // When only one tab exists: 0 = whichever is visible.
    final isLeavesTab = _showLeaves && (index == 0);
    final isRequestsTab = _showRequests && (!_showLeaves || index == 1);

    if (isLeavesTab) {
      ref.read(managerLeavesListProvider.notifier).refresh();
      ref.read(managerLeavesListProvider.notifier).refreshPendingCount();
    }
    if (isRequestsTab) {
      ref.read(managerRequestsListProvider.notifier).refresh();
      ref.read(managerRequestsListProvider.notifier).refreshPendingCount();
    }
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  /// Refresh both tabs + both pending counts (used on first open & manual refresh).
  void _refreshAll() {
    if (_showLeaves) {
      ref.read(managerLeavesListProvider.notifier).refresh();
      ref.read(managerLeavesListProvider.notifier).refreshPendingCount();
    }
    if (_showRequests) {
      ref.read(managerRequestsListProvider.notifier).refresh();
      ref.read(managerRequestsListProvider.notifier).refreshPendingCount();
    }
  }

  void _tryAutoOpenLeave() {
    if (_didAutoOpen || widget.openLeaveId == null) return;
    final leavesState = ref.read(managerLeavesListProvider);
    if (leavesState.isLoading || leavesState.items.isEmpty) return;

    final targetId = int.tryParse(widget.openLeaveId!);
    if (targetId == null) return;

    final target = leavesState.items.cast<ManagerLeave?>().firstWhere(
          (r) => r!.id == targetId,
          orElse: () => null,
        );
    if (target != null) {
      _didAutoOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          backgroundColor: context.appColors.bgCard,
          builder: (_) => _ManagerLeaveDetailSheet(leave: target),
        );
      });
    }
  }

  void _tryAutoOpenRequest() {
    if (_didAutoOpen || widget.openRequestId == null) return;
    final requestsState = ref.read(managerRequestsListProvider);
    if (requestsState.isLoading || requestsState.items.isEmpty) return;

    final targetId = int.tryParse(widget.openRequestId!);
    if (targetId == null) return;

    final target = requestsState.items.cast<ManagerRequest?>().firstWhere(
          (r) => r!.id == targetId,
          orElse: () => null,
        );
    if (target != null) {
      _didAutoOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          backgroundColor: context.appColors.bgCard,
          builder: (_) => _ManagerRequestDetailSheet(request: target),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild tabs whenever auth flags change.
    ref.watch(authProvider);
    _ensureTabController();

    // Auto-open bottomsheet from notification deep-link
    if (!_didAutoOpen) {
      if (widget.openLeaveId != null) {
        ref.watch(managerLeavesListProvider);
        _tryAutoOpenLeave();
        // Switch to leaves tab
        if (_showLeaves && _tabController != null) {
          _tabController!.index = 0;
        }
      }
      if (widget.openRequestId != null) {
        ref.watch(managerRequestsListProvider);
        _tryAutoOpenRequest();
        // Switch to requests tab
        if (_showRequests && _tabController != null) {
          final idx = _showLeaves ? 1 : 0;
          _tabController!.index = idx;
        }
      }
    }

    // Pending counts from lightweight providers (do NOT depend on authProvider
    // so they won't trigger a GoRouter rebuild).
    final leavesCount = ref.watch(pendingLeavesCountProvider);
    final requestsCount = ref.watch(pendingRequestsCountProvider);

    String labelWithCount(String base, int count) =>
        count > 0 ? '$base ($count)' : base;

    final tabs = <Tab>[
      if (_showLeaves)
        Tab(text: labelWithCount('Leaves'.tr(context), leavesCount)),
      if (_showRequests)
        Tab(text: labelWithCount('Requests'.tr(context), requestsCount)),
    ];
    final views = <Widget>[
      if (_showLeaves) const _ManagerLeavesTab(),
      if (_showRequests) const _ManagerRequestsTab(),
    ];
    final showTabBar = tabs.length > 1;

    // When only one tab is visible the TabBar is hidden, so the AppBar title
    // must clarify which list the user is looking at — otherwise a manager
    // who only handles employee requests would just see "Approvals" with no
    // hint that leaves are filtered out entirely.
    final String title;
    if (_showLeaves && !_showRequests) {
      title = 'Leave approvals'.tr(context);
    } else if (_showRequests && !_showLeaves) {
      title = 'Request approvals'.tr(context);
    } else {
      title = 'Approvals'.tr(context);
    }

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: title,
            onRefresh: _refreshAll,
          ),

          // ── Company filter (only if user manages multiple companies) ──
          const _CompanyFilterBar(),

          // ── TabBar (hidden when only one tab is visible) ──
          if (showTabBar)
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
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                dividerHeight: 0.5,
                dividerColor: context.appColors.gray200,
                splashBorderRadius: BorderRadius.circular(0),
                tabs: tabs,
              ),
            ),

          // ── TabBarView ──
          Expanded(
            child: views.isEmpty
                ? Center(
                    child: Text(
                      'No approvals available'.tr(context),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: context.appColors.textMuted,
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: views,
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Company Filter Bar — only renders if the user has 2+ managed companies.
// ═══════════════════════════════════════════════════════════════════

class _CompanyFilterBar extends ConsumerWidget {
  const _CompanyFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(authProvider).managedCompanies;
    if (companies.length < 2) return const SizedBox.shrink();

    final selectedId = ref.watch(selectedApprovalCompanyIdProvider);

    return Container(
      width: double.infinity,
      color: context.appColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.business_outlined,
              size: 18, color: context.appColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '${'Company'.tr(context)}:',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: selectedId,
                hint: Text(
                  'All companies'.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: context.appColors.textMuted,
                  ),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All companies'.tr(context),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                  ),
                  for (final c in companies)
                    DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                    ),
                ],
                onChanged: (value) {
                  ref
                      .read(selectedApprovalCompanyIdProvider.notifier)
                      .state = value;
                },
              ),
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
    ('awaiting_me', 'Awaiting your approval'),
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

class _ManagerLeaveTile extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startFormatted = _formatLeaveDate(leave.startDate);
    final endFormatted = _formatLeaveDate(leave.endDate);
    final days = leave.totalDays;
    final daysLabel = days == days.truncateToDouble()
        ? '${days.toInt()} ${'d'.tr(context)}'
        : '${days.toStringAsFixed(1)} ${'d'.tr(context)}';

    return GestureDetector(
      onTap: () => _showDetailSheet(context, ref),
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

            // ── Row 3: Employee name (start) | Download button (end) ──
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
                  )
                else
                  const Spacer(),
                if (leave.hasAttachment)
                  _AttachmentMiniButton(
                    attachmentPath: leave.attachmentPath,
                    attachmentUrl: leave.attachmentUrl,
                    fileKey: leave.requestNumber ?? 'leave-${leave.id}',
                  ),
              ],
            ),

            // ── Row 4: Current approver (shown when not this user's turn) ──
            if (!leave.canDecide)
              ..._buildCurrentApproverRow(context, leave.approvalHistory),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCurrentApproverRow(
      BuildContext context, List<ApprovalHistoryItem> history) {
    final current = history.cast<ApprovalHistoryItem?>().firstWhere(
          (h) => h!.isCurrent && h.decision == 'pending',
          orElse: () => null,
        );
    if (current == null) return const [];
    final name = current.approverName ?? current.label;
    if (name.isEmpty) return const [];
    return [
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 13, color: AppColors.warning),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${'Awaiting'.tr(context)}: $name',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _showDetailSheet(BuildContext context, WidgetRef ref) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black26,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final repo = ref.read(managerLeaveRepositoryProvider);
      final fresh = await repo.getLeaveDetail(leave.id);
      rootNav.pop();
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: context.appColors.bgCard,
        builder: (_) => _ManagerLeaveDetailSheet(leave: fresh),
      );
    } catch (_) {
      rootNav.pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load details'.tr(context))),
        );
      }
    }
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

  bool get _canDecide => widget.leave.canDecide;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fixed header (handle + close + title + status) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
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
                      style: TextStyle(
                        fontFamily: 'Cairo',
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
            ],
          ),
        ),
        Divider(height: 1, color: context.appColors.gray200),

        // ── Scrollable body ──
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
              value: AppFuns.formatApiDateTime(r.createdAt),
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
                value: AppFuns.formatApiDateTime(r.approvedAt!),
              ),

            // ── Approval Timeline ──
            if (r.approvalHistory.isNotEmpty || r.approvalChain.isNotEmpty) ...[
              const SizedBox(height: 8),
              ApprovalTimeline(
                chain: r.approvalChain,
                history: r.approvalHistory,
                totalLevels: r.totalLevels,
                currentLevel: r.currentApprovalLevel,
              ),
            ],

            // ── Attachment (when no decision section will follow) ──
            if (r.hasAttachment && !_canDecide) ...[
              const SizedBox(height: 12),
              _AttachmentMiniButton(
                attachmentPath: r.attachmentPath,
                attachmentUrl: r.attachmentUrl,
                fileKey: r.requestNumber ?? 'leave-${r.id}',
                fullWidth: true,
              ),
            ],

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
                      decideState.fieldError('notes') ?? decideState.fieldError('rejection_reason'),
                ),
              ),

              // ── Attachment download / open (above action buttons) ──
              if (r.hasAttachment) ...[
                const SizedBox(height: 12),
                _AttachmentMiniButton(
                  attachmentPath: r.attachmentPath,
                  attachmentUrl: r.attachmentUrl,
                  fileKey: r.requestNumber ?? 'leave-${r.id}',
                  fullWidth: true,
                ),
              ],
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
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 2: Manager Requests (existing)
// ═══════════════════════════════════════════════════════════════════

class _ManagerRequestsTab extends ConsumerWidget {
  const _ManagerRequestsTab();

  static const _statusFilters = [
    ('awaiting_me', 'Awaiting your approval'),
    (null, 'All'),
    ('pending', 'Pending'),
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

class _ManagerRequestTile extends ConsumerWidget {
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

  String _formatAmount(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetailSheet(context, ref),
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
                if (request.hasAttachment)
                  _AttachmentMiniButton(
                    attachmentPath: request.attachmentPath,
                    attachmentUrl: request.attachmentUrl,
                    fileKey: request.requestNumber ?? 'req-${request.id}',
                  ),
              ],
            ),

            // ── Row 3: Amount + Currency (financial requests) ──
            if (request.amount != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatAmount(request.amount!)} ${request.currency?.code ?? ''}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ],

            // ── Row 4: Current approver (shown when not this user's turn) ──
            if (!request.canDecide)
              ..._buildCurrentApproverRow(context, request.approvalHistory),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCurrentApproverRow(
      BuildContext context, List<ApprovalHistoryItem> history) {
    final current = history.cast<ApprovalHistoryItem?>().firstWhere(
          (h) => h!.isCurrent && h.decision == 'pending',
          orElse: () => null,
        );
    if (current == null) return const [];
    final name = current.approverName ?? current.label;
    if (name.isEmpty) return const [];
    return [
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 13, color: AppColors.warning),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${'Awaiting'.tr(context)}: $name',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _showDetailSheet(BuildContext context, WidgetRef ref) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black26,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final repo = ref.read(managerRequestRepositoryProvider);
      final fresh = await repo.getRequestDetail(request.id);
      rootNav.pop();
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: context.appColors.bgCard,
        builder: (_) => _ManagerRequestDetailSheet(request: fresh),
      );
    } catch (_) {
      rootNav.pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load details'.tr(context))),
        );
      }
    }
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

  String _formatAmount(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  bool get _canDecide => widget.request.canDecide;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fixed header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
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
            ],
          ),
        ),
        Divider(height: 1, color: context.appColors.gray200),

        // ── Scrollable body ──
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            if (r.amount != null)
              _InfoRow(
                icon: '💰',
                label: 'Amount'.tr(context),
                value: '${_formatAmount(r.amount!)} ${r.currency?.code ?? ''}',
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

            // ── Approval Timeline ──
            if (r.approvalHistory.isNotEmpty || r.approvalChain.isNotEmpty) ...[
              const SizedBox(height: 8),
              ApprovalTimeline(
                chain: r.approvalChain,
                history: r.approvalHistory,
                totalLevels: r.totalLevels,
                currentLevel: r.currentApprovalLevel,
              ),
            ],

            // ── Attachment (when no decision section will follow) ──
            if (r.hasAttachment && !_canDecide) ...[
              const SizedBox(height: 12),
              _AttachmentMiniButton(
                attachmentPath: r.attachmentPath,
                attachmentUrl: r.attachmentUrl,
                fileKey: r.requestNumber ?? 'req-${r.id}',
                fullWidth: true,
              ),
            ],

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
                  errorText: decideState.fieldError('notes') ?? decideState.fieldError('response_notes'),
                ),
              ),

              // ── Attachment download / open (above action buttons) ──
              if (r.hasAttachment) ...[
                const SizedBox(height: 12),
                _AttachmentMiniButton(
                  attachmentPath: r.attachmentPath,
                  attachmentUrl: r.attachmentUrl,
                  fileKey: r.requestNumber ?? 'req-${r.id}',
                  fullWidth: true,
                ),
              ],
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
        ),
      ],
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

// ═══════════════════════════════════════════════════════════════════
// Attachment mini button — compact "download / open" button used inside
// the leave and request approval cards. Stops the parent card's tap from
// firing so the user can grab the file without opening the detail sheet.
// ═══════════════════════════════════════════════════════════════════

class _AttachmentMiniButton extends ConsumerStatefulWidget {
  final String? attachmentPath;
  final String? attachmentUrl;
  final String fileKey;
  final bool fullWidth;

  const _AttachmentMiniButton({
    required this.attachmentPath,
    required this.attachmentUrl,
    required this.fileKey,
    this.fullWidth = false,
  });

  @override
  ConsumerState<_AttachmentMiniButton> createState() =>
      _AttachmentMiniButtonState();
}

class _AttachmentMiniButtonState extends ConsumerState<_AttachmentMiniButton> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  String get _path =>
      widget.attachmentPath ?? widget.attachmentUrl ?? '';

  Future<void> _checkExists() async {
    if (kIsWeb || _path.isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);
    final path = await svc.localPath(
      key: widget.fileKey,
      attachmentPath: _path,
    );
    final ok = await svc.exists(
      key: widget.fileKey,
      attachmentPath: _path,
    );
    if (!mounted) return;
    setState(() {
      _localPath = path;
      _exists = ok;
    });
  }

  Future<void> _onTap() async {
    if (_path.isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);

    if (kIsWeb) {
      try {
        await svc.openInBrowser(_path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      return;
    }

    if (_exists && _localPath != null) {
      try {
        await svc.openLocal(_localPath!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      return;
    }

    setState(() => _downloading = true);
    try {
      final path = await svc.download(
        key: widget.fileKey,
        attachmentPath: _path,
      );
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _exists = path != null;
        _localPath = path;
      });
      if (path != null) {
        await svc.openLocal(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Failed to download file'.tr(context)}\n$e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOpen = !kIsWeb && _exists;
    final color = showOpen ? AppColors.success : AppColors.primaryMid;
    final icon = _downloading
        ? Icons.hourglass_top_rounded
        : showOpen
            ? Icons.folder_open_rounded
            : Icons.download_rounded;
    final label = _downloading
        ? 'Downloading...'.tr(context)
        : showOpen
            ? 'Open file'.tr(context)
            : 'Download file'.tr(context);

    if (widget.fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _downloading ? null : _onTap,
          icon: _downloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.7),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    // Compact pill — used inside list cards. GestureDetector with opaque
    // behavior blocks the parent card's onTap so a tap on the button doesn't
    // also open the detail sheet.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _downloading ? null : _onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
