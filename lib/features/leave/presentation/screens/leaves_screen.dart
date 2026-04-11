import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/notification_route_handler.dart';
import '../../../../core/services/notifications_bus.dart';
import '../../../../core/utils/app_funs.dart';
import '../../../../shared/widgets/approval_timeline.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/models/leave_models.dart';
import '../providers/leave_providers.dart';

/// Public helper to show the employee leave detail bottomsheet from any screen.
void showEmployeeLeaveDetailSheet(BuildContext context, LeaveRequest request,
    {VoidCallback? onChanged}) {
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
    builder: (_) => _LeaveDetailSheet(
      request: request,
      onChanged: onChanged ?? () {},
    ),
  );
}

class LeavesScreen extends ConsumerStatefulWidget {
  final String? openId;
  const LeavesScreen({super.key, this.openId});

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends ConsumerState<LeavesScreen> {
  int _tab = 0;
  DateTimeRange? _dateRange;
  bool _didAutoOpen = false;
  StreamSubscription<String>? _routeSub;

  static const _labels = ['Pending', 'All', 'Draft', 'Approved', 'Rejected'];
  static const _statusMap = ['pending', null, 'draft', 'approved', 'rejected'];
  static const _colors = [
    AppColors.warning,    // Pending
    AppColors.teal,       // All
    AppColors.primaryMid, // Draft
    AppColors.success,    // Approved
    AppColors.error,      // Rejected
  ];

  static final _dateFormat = DateFormat('yyyy-MM-dd', 'en');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadWithFilter();
      // When opened via notification deep-link, switch to "All" tab
      // so the target request is visible regardless of its status.
      if (widget.openId != null) {
        setState(() => _tab = 1); // "All"
      }
    });

    // Auto-refresh when a foreground notification about employee leaves arrives.
    _routeSub = NotificationsBus.routeStream.listen((route) {
      final parsed = parseNotificationRoute(route);
      if (parsed != null && parsed.type == NotificationRouteType.employeeLeave) {
        _loadWithFilter();
      }
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    super.dispose();
  }

  void _loadWithFilter() {
    ref.read(leavesListProvider.notifier).load(
      status: _statusMap[_tab],
      dateFrom: _dateRange != null ? _dateFormat.format(_dateRange!.start) : null,
      dateTo: _dateRange != null ? _dateFormat.format(_dateRange!.end) : null,
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
      locale: Localizations.localeOf(context),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryMid,
              onPrimary: Colors.white,
              surface: context.appColors.bgCard,
              onSurface: context.appColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadWithFilter();
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    _loadWithFilter();
  }

  void _tryAutoOpen(LeavesListState state) {
    if (_didAutoOpen || widget.openId == null) return;
    if (state.isLoading || state.requests.isEmpty) return;
    _didAutoOpen = true;

    final targetId = int.tryParse(widget.openId!);
    if (targetId == null) return;

    final target = state.requests.cast<LeaveRequest?>().firstWhere(
          (r) => r!.id == targetId,
          orElse: () => null,
        );
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLeaveDetailSheet(context, ref, target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leavesListProvider);

    // Auto-open bottomsheet when navigated from notification
    _tryAutoOpen(state);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Leaves'.tr(context),
            onRefresh: _loadWithFilter,
            leading: GestureDetector(
              onTap: () => context.go('/leaves/create'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
            bottom: _buildFilterRow(context, state),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: LoadingIndicator())
                : state.error != null
                    ? ErrorFullScreen(
                        error: state.error!,
                        onRetry: _loadWithFilter,
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadWithFilter(),
                        child: _buildList(context, ref, state),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, LeavesListState state) {
    final s = state.summary;
    final counts = s != null
        ? [s.pending, s.total, s.draft, s.approved, s.rejected]
        : null;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(_labels.length, (i) {
              final v = counts != null ? '${counts[i]}' : '...';
              return Padding(
                padding: EdgeInsetsDirectional.only(end: i < _labels.length - 1 ? 6 : 0),
                child: _filterPill(v, _labels[i].tr(context), _colors[i], i),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        _buildDateRangeRow(context),
      ],
    );
  }

  Widget _buildDateRangeRow(BuildContext context) {
    final hasRange = _dateRange != null;
    final label = hasRange
        ? '${AppFuns.formatDate(_dateRange!.start, withDay: false)}  →  ${AppFuns.formatDate(_dateRange!.end, withDay: false)}'
        : 'Filter by date'.tr(context);

    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasRange
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasRange
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 16,
              color: hasRange ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: hasRange ? FontWeight.w700 : FontWeight.w500,
                  color: hasRange ? Colors.white : Colors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasRange) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearDateRange,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String count, String label, Color accentColor, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () {
        if (_tab == index) return;
        setState(() => _tab = index);
        _loadWithFilter();
      },
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: accentColor,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, LeavesListState state) {
    if (state.requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyStateWidget(
            icon: '📋',
            title: 'No leave requests'.tr(context),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      itemCount: state.requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = state.requests[index];
        return _LeaveRequestCard(
          key: ValueKey('leave-card-${r.id}'),
          request: r,
          onTap: () => _showLeaveDetailSheet(context, ref, r),
        );
      },
    );
  }

  Future<void> _showLeaveDetailSheet(BuildContext context, WidgetRef ref, LeaveRequest r) async {
    // Show loading overlay while fetching fresh data from server.
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
      final repo = ref.read(leaveRepositoryProvider);
      final fresh = await repo.getLeaveDetail(r.id!);
      rootNav.pop(); // dismiss loading
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
        builder: (_) => _LeaveDetailSheet(
          request: fresh,
          onChanged: () => _loadWithFilter(),
        ),
      );
    } catch (_) {
      rootNav.pop(); // dismiss loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load details'.tr(context))),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Leave Request Card
// ═══════════════════════════════════════════════════════════════════

class _LeaveRequestCard extends ConsumerStatefulWidget {
  final LeaveRequest request;
  final VoidCallback onTap;

  const _LeaveRequestCard({super.key, required this.request, required this.onTap});

  @override
  ConsumerState<_LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends ConsumerState<_LeaveRequestCard> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  Future<void> _checkExists() async {
    final r = widget.request;
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty || r.requestNumber == null) {
      return;
    }
    final svc = ref.read(attachmentServiceProvider);
    final path = await svc.localPath(
      key: r.requestNumber!,
      attachmentPath: r.attachmentPath!,
    );
    final ok = await svc.exists(
      key: r.requestNumber!,
      attachmentPath: r.attachmentPath!,
    );
    if (!mounted) return;
    setState(() {
      _localPath = path;
      _exists = ok;
    });
  }

  Future<void> _onDownloadOrOpen() async {
    final r = widget.request;
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty || r.requestNumber == null) {
      return;
    }
    final svc = ref.read(attachmentServiceProvider);

    // Web: just open in a new tab.
    if (kIsWeb) {
      try {
        await svc.openInBrowser(r.attachmentPath!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
      return;
    }

    // If already downloaded → just open it.
    if (_exists && _localPath != null) {
      try {
        await svc.openLocal(_localPath!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
      return;
    }

    // Otherwise → download then refresh state.
    setState(() => _downloading = true);
    try {
      final path = await svc.download(
        key: r.requestNumber!,
        attachmentPath: r.attachmentPath!,
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
    } catch (e, st) {
      // Detailed log so backend / network issues are easy to diagnose.
      final url = svc.buildUrl(r.attachmentPath!);
      print('err download $url: $e');
      print(st);
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
    final r = widget.request;
    final onTap = widget.onTap;
    final startFormatted = _formatDate(r.startDate);
    final endFormatted = _formatDate(r.endDate);
    final days = r.totalDays;
    final daysLabel = days == days.truncateToDouble()
        ? '${days.toInt()} ${'d'.tr(context)}'
        : '${days.toStringAsFixed(1)} ${'d'.tr(context)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              // Row 1: Status | Leave type | Days
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      r.leaveType?.name ?? '',
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
                        text: _statusLabel(r.status).tr(context),
                        type: _statusType(r.status),
                        dot: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: From — To
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
                  Text('—', style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 16, color: context.appColors.textMuted)),
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
              // Row 3: Approver (start) | Attachment download (end)
              Builder(builder: (context) {
                final isAr =
                    Localizations.localeOf(context).languageCode == 'ar';
                final pendingApprover = r.status == 'pending'
                    ? r.currentApproverDisplay(isAr)
                    : '';
                final hasApprover = pendingApprover.isNotEmpty;
                final hasAttachment =
                    r.attachmentPath != null && r.attachmentPath!.isNotEmpty;
                if (!hasApprover && !hasAttachment) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (hasApprover)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_top,
                                  size: 14, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${'Awaiting approval from'.tr(context)}: $pendingApprover',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      if (hasAttachment) _buildAttachmentButton(context),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentButton(BuildContext context) {
    if (_downloading) {
      return Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primaryMid.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryMid),
        ),
      );
    }
    final showOpen = kIsWeb ? false : _exists;
    return GestureDetector(
      onTap: _onDownloadOrOpen,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: showOpen
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.primaryMid.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          showOpen ? Icons.folder_open_rounded : Icons.download_rounded,
          size: 18,
          color: showOpen ? AppColors.success : AppColors.primaryMid,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      return AppFuns.formatDate(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'pending': return 'Pending';
      case 'cancelled': return 'Cancelled';
      case 'draft': return 'Draft';
      default: return status;
    }
  }

  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'approved';
      case 'rejected': return 'rejected';
      case 'pending': return 'pending';
      default: return 'info';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Leave Detail Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _LeaveDetailSheet extends ConsumerStatefulWidget {
  final LeaveRequest request;
  final VoidCallback onChanged;

  const _LeaveDetailSheet({required this.request, required this.onChanged});

  @override
  ConsumerState<_LeaveDetailSheet> createState() => _LeaveDetailSheetState();
}

class _LeaveDetailSheetState extends ConsumerState<_LeaveDetailSheet> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  Future<void> _checkExists() async {
    final r = widget.request;
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty || r.requestNumber == null) {
      return;
    }
    final svc = ref.read(attachmentServiceProvider);
    final path = await svc.localPath(
      key: r.requestNumber!,
      attachmentPath: r.attachmentPath!,
    );
    final ok = await svc.exists(
      key: r.requestNumber!,
      attachmentPath: r.attachmentPath!,
    );
    if (!mounted) return;
    setState(() {
      _localPath = path;
      _exists = ok;
    });
  }

  Future<void> _onDownloadOrOpen() async {
    final r = widget.request;
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty || r.requestNumber == null) {
      return;
    }
    final svc = ref.read(attachmentServiceProvider);

    if (kIsWeb) {
      try {
        await svc.openInBrowser(r.attachmentPath!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      return;
    }

    if (_exists && _localPath != null) {
      try {
        await svc.openLocal(_localPath!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      return;
    }

    setState(() => _downloading = true);
    try {
      final path = await svc.download(
        key: r.requestNumber!,
        attachmentPath: r.attachmentPath!,
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
    } catch (e, st) {
      final url = svc.buildUrl(r.attachmentPath!);
      print('err download $url: $e');
      print(st);
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
    final r = widget.request;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fixed header (handle + close + title + status badge) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Status
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
                // Info Rows
                if (r.requestNumber != null)
            _LeaveDetailRow(icon: '🔢', label: 'Code'.tr(context), value: r.requestNumber!),
          _LeaveDetailRow(icon: '📅', label: 'From'.tr(context), value: AppFuns.formatDate(DateTime.tryParse(r.startDate))),
          _LeaveDetailRow(icon: '📅', label: 'To'.tr(context), value: AppFuns.formatDate(DateTime.tryParse(r.endDate))),
          _LeaveDetailRow(
            icon: '⏱',
            label: 'Total days'.tr(context),
            value: '${r.totalDays.toStringAsFixed(1)} ${'day'.tr(context)}',
          ),
          if (r.reason != null && r.reason!.isNotEmpty)
            _LeaveDetailRow(
              icon: '📝',
              label: 'Reason'.tr(context),
              value: r.reason!,
            ),
          if (r.attachmentPath != null && r.attachmentPath!.isNotEmpty)
            _LeaveDetailRow(
              icon: '📎',
              label: 'Attachment'.tr(context),
              value: r.attachmentName ?? '${r.requestNumber ?? ''}.${_extOf(r.attachmentPath!)}',
            ),
          if (r.rejectionReason != null && r.rejectionReason!.isNotEmpty)
            _LeaveDetailRow(
              icon: '❌',
              label: 'Rejection reason'.tr(context),
              value: r.rejectionReason!,
            ),
          if (r.createdAt != null)
            _LeaveDetailRow(
              icon: '🕐',
              label: 'Created at'.tr(context),
              value: _formatDateTime(r.createdAt!),
            ),

          // Approval Timeline (stepper)
          if (r.approvalHistory.isNotEmpty || r.approvalChain.isNotEmpty) ...[
            const SizedBox(height: 4),
            ApprovalTimeline(
              chain: r.approvalChain,
              history: r.approvalHistory,
              totalLevels: r.totalLevels ??
                  (r.approvalChain.isNotEmpty
                      ? r.approvalChain.length
                      : r.approvalHistory.length),
              currentLevel: r.currentApprovalLevel,
            ),
          ],

          // Attachment download/open (full width, above action buttons)
          if (r.attachmentPath != null && r.attachmentPath!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAttachmentButton(context),
          ],

          // Action buttons
          if (r.canSubmit || r.canDelete) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (r.canSubmit)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _submitLeave(context, r.id!),
                      icon: const Icon(Icons.send, size: 18),
                      label: Text('Submit for approval'.tr(context),
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (r.canSubmit && r.canDelete) const SizedBox(width: 10),
                if (r.canDelete)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteLeave(context, r.id!),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('Delete'.tr(context),
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  String _extOf(String path) {
    final cleaned = path.split('?').first.split('#').first;
    final lastDot = cleaned.lastIndexOf('.');
    final lastSlash = cleaned.lastIndexOf('/');
    if (lastDot > lastSlash && lastDot != -1) {
      return cleaned.substring(lastDot + 1).toLowerCase();
    }
    return 'file';
  }

  Widget _buildAttachmentButton(BuildContext context) {
    final showOpen = kIsWeb ? false : _exists;
    final bgColor = showOpen ? AppColors.success : AppColors.primaryMid;
    final label = _downloading
        ? 'Downloading...'.tr(context)
        : showOpen
            ? 'Open file'.tr(context)
            : 'Download file'.tr(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _downloading ? null : _onDownloadOrOpen,
        icon: _downloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                showOpen ? Icons.folder_open_rounded : Icons.download_rounded,
                size: 20,
              ),
        label: Text(
          label,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _submitLeave(BuildContext context, int id) async {
    Navigator.pop(context);
    final success = await ref.read(leavesListProvider.notifier).submitLeave(id);
    widget.onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Request submitted successfully'.tr(context)
              : 'Failed to submit request'.tr(context)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _deleteLeave(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete request'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this request?'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr(context), style: const TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              final success = await ref.read(leavesListProvider.notifier).deleteLeave(id);
              widget.onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Request deleted successfully'.tr(context)
                        : 'Failed to delete request'.tr(context)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text('Delete'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateStr) {
    try {
      return AppFuns.formatDateTime(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'pending': return 'Pending';
      case 'cancelled': return 'Cancelled';
      case 'draft': return 'Draft';
      default: return status;
    }
  }

  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'approved';
      case 'rejected': return 'rejected';
      case 'pending': return 'pending';
      default: return 'info';
    }
  }
}

class _LeaveDetailRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool underline;

  const _LeaveDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11, color: context.appColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: valueColor ?? context.appColors.textPrimary,
                    decoration: underline ? TextDecoration.underline : null,
                    decorationColor: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
