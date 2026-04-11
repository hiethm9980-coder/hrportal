import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../../shared/widgets/approval_timeline.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/models/request_models.dart';
import '../providers/request_providers.dart';

const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'zip'];
const _maxFileSizeMb = 10;

// ═══════════════════════════════════════════════════════════════════
// Public helper to show employee request detail from any screen
// ═══════════════════════════════════════════════════════════════════

/// Show employee request detail bottomsheet from any screen.
void showEmployeeRequestDetailSheet(BuildContext context, EmployeeRequest request,
    {VoidCallback? onChanged}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: context.appColors.bgCard,
    builder: (_) => _RequestDetailSheet(
      request: request,
      onChanged: onChanged ?? () {},
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Requests List Screen
// ═══════════════════════════════════════════════════════════════════

class RequestsScreen extends ConsumerStatefulWidget {
  final String? openId;
  const RequestsScreen({super.key, this.openId});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  int _tab = 0;
  DateTimeRange? _dateRange;
  bool _didAutoOpen = false;
  StreamSubscription<String>? _routeSub;

  static const _labels = ['Pending', 'All', 'Draft', 'Approved', 'Rejected'];
  static const _statusMap = ['pending', null, 'draft', 'approved', 'rejected'];
  static const _colors = [
    AppColors.warning,
    AppColors.teal,
    AppColors.primaryMid,
    AppColors.success,
    AppColors.error,
  ];

  static final _dateFormat = DateFormat('yyyy-MM-dd', 'en');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadWithFilter();
      if (widget.openId != null) {
        setState(() => _tab = 1); // "All"
      }
    });

    // Auto-refresh when a foreground notification about employee requests arrives.
    _routeSub = NotificationsBus.routeStream.listen((route) {
      final parsed = parseNotificationRoute(route);
      if (parsed != null && parsed.type == NotificationRouteType.employeeRequest) {
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
    ref.read(requestsListProvider.notifier).load(
          status: _statusMap[_tab],
          dateFrom: _dateRange != null
              ? _dateFormat.format(_dateRange!.start)
              : null,
          dateTo: _dateRange != null
              ? _dateFormat.format(_dateRange!.end)
              : null,
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

  void _tryAutoOpen(RequestsListState state) {
    if (_didAutoOpen || widget.openId == null) return;
    if (state.isLoading || state.requests.isEmpty) return;
    _didAutoOpen = true;

    final targetId = int.tryParse(widget.openId!);
    if (targetId == null) return;

    final target = state.requests.cast<EmployeeRequest?>().firstWhere(
          (r) => r!.id == targetId,
          orElse: () => null,
        );
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDetailSheet(context, target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestsListProvider);

    // Auto-open bottomsheet when navigated from notification
    _tryAutoOpen(state);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Requests'.tr(context),
            onRefresh: _loadWithFilter,
            leading: GestureDetector(
              onTap: () => context.go('/requests/create'),
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
                        child: _buildList(context, state),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, RequestsListState state) {
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
                padding: EdgeInsetsDirectional.only(
                    end: i < _labels.length - 1 ? 6 : 0),
                child:
                    _filterPill(v, _labels[i].tr(context), _colors[i], i),
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
                  child: const Icon(Icons.close,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterPill(
      String count, String label, Color accentColor, int index) {
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

  Widget _buildList(BuildContext context, RequestsListState state) {
    if (state.requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyStateWidget(
            icon: '📋',
            title: 'No requests'.tr(context),
            subtitle: 'Tap + to create a new request'.tr(context),
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
        return _RequestCard(
          key: ValueKey('request-card-${r.id}'),
          request: r,
          onTap: () => _showDetailSheet(context, r),
        );
      },
    );
  }

  Future<void> _showDetailSheet(BuildContext context, EmployeeRequest r) async {
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
      final repo = ref.read(requestRepositoryProvider);
      final fresh = await repo.getRequestDetail(r.id);
      rootNav.pop(); // dismiss loading
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: context.appColors.bgCard,
        builder: (_) => _RequestDetailSheet(
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
// Request Card
// ═══════════════════════════════════════════════════════════════════

class _RequestCard extends ConsumerStatefulWidget {
  final EmployeeRequest request;
  final VoidCallback onTap;

  const _RequestCard({super.key, required this.request, required this.onTap});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  String get _attachmentKey {
    final r = widget.request;
    return r.requestNumber ?? 'req-${r.id}';
  }

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  Future<void> _checkExists() async {
    final r = widget.request;
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);
    final path = await svc.localPath(
      key: _attachmentKey,
      attachmentPath: r.attachmentPath!,
    );
    final ok = await svc.exists(
      key: _attachmentKey,
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
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);

    if (kIsWeb) {
      try {
        await svc.openInBrowser(r.attachmentPath!);
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
        key: _attachmentKey,
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
    final r = widget.request;
    final typeName =
        r.requestType?.name ?? r.requestTypeLabel ?? 'Request'.tr(context);
    final subject = r.subject ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Type | Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      typeName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    text: _statusLabel(r.status).tr(context),
                    type: _statusType(r.status),
                    dot: true,
                  ),
                ],
              ),

              // Row 2: Subject
              if (subject.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subject,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Row 3: Amount (if financial)
              if (r.amount != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 14, color: AppColors.teal),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatAmount(r.amount!)} ${r.currency?.code ?? ''}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],

              // Row 4: Approver (start) | Attachment (end) — only if either exists
              if (() {
                final isAr =
                    Localizations.localeOf(context).languageCode == 'ar';
                final approverName =
                    r.isPending ? r.currentApproverDisplay(isAr) : '';
                return approverName.isNotEmpty ||
                    (r.attachmentPath != null &&
                        r.attachmentPath!.isNotEmpty);
              }()) ...[
                const SizedBox(height: 8),
                Builder(builder: (ctx) {
                  final isAr =
                      Localizations.localeOf(ctx).languageCode == 'ar';
                  final approverName =
                      r.isPending ? r.currentApproverDisplay(isAr) : '';
                  return Row(
                    children: [
                      if (approverName.isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top,
                                  size: 14, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${'Awaiting approval from'.tr(context)}: $approverName',
                                  style: const TextStyle(
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
                      if (r.attachmentPath != null &&
                          r.attachmentPath!.isNotEmpty)
                        _buildAttachmentButton(context),
                    ],
                  );
                }),
              ],

              // Row 5: Created date (end-aligned)
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  _formatCreatedDate(r.createdAt),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
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

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  String _formatCreatedDate(String dateStr) {
    try {
      return AppFuns.formatDate(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Request Detail Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _RequestDetailSheet extends ConsumerStatefulWidget {
  final EmployeeRequest request;
  final VoidCallback onChanged;

  const _RequestDetailSheet(
      {required this.request, required this.onChanged});

  @override
  ConsumerState<_RequestDetailSheet> createState() =>
      _RequestDetailSheetState();
}

class _RequestDetailSheetState extends ConsumerState<_RequestDetailSheet> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  String get _attachmentKey {
    final r = widget.request;
    return r.requestNumber ?? 'req-${r.id}';
  }

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  Future<void> _checkExists() async {
    final r = widget.request;
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);
    final path = await svc.localPath(
      key: _attachmentKey,
      attachmentPath: r.attachmentPath!,
    );
    final ok = await svc.exists(
      key: _attachmentKey,
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
    if (r.attachmentPath == null || r.attachmentPath!.isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);

    if (kIsWeb) {
      try {
        await svc.openInBrowser(r.attachmentPath!);
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
        key: _attachmentKey,
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
    final r = widget.request;
    final typeName =
        r.requestType?.name ?? r.requestTypeLabel ?? 'Request'.tr(context);

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
                    typeName,
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
            const SizedBox(height: 20),

            // Info rows
            if (r.requestNumber != null && r.requestNumber!.isNotEmpty)
              _DetailRow(
                  icon: '🔢',
                  label: 'Code'.tr(context),
                  value: r.requestNumber!),
            if (r.subject != null && r.subject!.isNotEmpty)
              _DetailRow(
                icon: '📝',
                label: 'Subject *'.tr(context).replaceAll(' *', ''),
                value: r.subject!,
              ),
            if (r.amount != null)
              _DetailRow(
                icon: '💰',
                label: 'Amount'.tr(context),
                value:
                    '${_formatAmount(r.amount!)} ${r.currency?.code ?? ''}',
              ),
            if (r.requestDate != null && r.requestDate!.isNotEmpty)
              _DetailRow(
                icon: '📅',
                label: 'Request date'.tr(context),
                value: AppFuns.formatDate(DateTime.tryParse(r.requestDate!)),
              ),
            if (r.description != null && r.description!.isNotEmpty)
              _DetailRow(
                icon: '📄',
                label: 'Details'.tr(context),
                value: r.description!,
                multiLine: true,
              ),
            if (r.attachmentPath != null && r.attachmentPath!.isNotEmpty)
              _DetailRow(
                icon: '📎',
                label: 'Attachment'.tr(context),
                value: r.attachmentName ??
                    '$_attachmentKey.${_extOf(r.attachmentPath!)}',
              ),
            if (r.responseNotes != null && r.responseNotes!.isNotEmpty)
              _DetailRow(
                icon: '💬',
                label: 'Response notes'.tr(context),
                value: r.responseNotes!,
                multiLine: true,
              ),
            if (r.respondedAt != null && r.respondedAt!.isNotEmpty)
              _DetailRow(
                icon: '⏰',
                label: 'Responded at'.tr(context),
                value: _formatDateTime(r.respondedAt!),
              ),
            _DetailRow(
              icon: '🕐',
              label: 'Created at'.tr(context),
              value: _formatDateTime(r.createdAt),
            ),

            // ── Approval Timeline (steppers) ────────────────────────
            if (r.approvalHistory.isNotEmpty ||
                r.approvalChain.isNotEmpty) ...[
              const SizedBox(height: 16),
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

            // Attachment download/open button (full width)
            if (r.attachmentPath != null && r.attachmentPath!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAttachmentButton(context),
            ],

            // Action buttons (Submit / Delete)
            if (r.canSubmit || r.canDelete) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (r.canSubmit)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitRequest(context, r.id),
                        icon: const Icon(Icons.send, size: 18),
                        label: Text('Submit for approval'.tr(context),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMid,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (r.canSubmit && r.canDelete) const SizedBox(width: 10),
                  if (r.canDelete)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteRequest(context, r.id),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text('Delete'.tr(context),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
    );
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
                showOpen
                    ? Icons.folder_open_rounded
                    : Icons.download_rounded,
                size: 20,
              ),
        label: Text(
          label,
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _submitRequest(BuildContext context, int id) async {
    Navigator.pop(context);
    final success =
        await ref.read(requestsListProvider.notifier).submitRequest(id);
    widget.onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Request submitted successfully'.tr(context)
              : 'Failed to submit request'.tr(context)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _deleteRequest(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete request'.tr(context),
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete this request?'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              final success = await ref
                  .read(requestsListProvider.notifier)
                  .deleteRequest(id);
              widget.onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Request deleted successfully'.tr(context)
                        : 'Failed to delete request'.tr(context)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text('Delete'.tr(context),
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
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

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  String _formatDateTime(String dateStr) {
    try {
      return AppFuns.formatDateTime(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Detail Row (shared between sheet & list)
// ═══════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool multiLine;

  const _DetailRow({
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
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: context.appColors.textMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: multiLine ? 10 : 2,
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
// (Approval Timeline moved to lib/shared/widgets/approval_timeline.dart)
// ═══════════════════════════════════════════════════════════════════

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
    case 'draft':
      return 'Draft';
    default:
      return status;
  }
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

// ═══════════════════════════════════════════════════════════════════
// Create Request Screen
// ═══════════════════════════════════════════════════════════════════

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _requestDate;

  static final _apiDateFormat = DateFormat('yyyy-MM-dd', 'en');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(requestTypesProvider.notifier).load();
      ref.read(currenciesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(createRequestFormProvider);
    final notifier = ref.read(createRequestFormProvider.notifier);
    final typesState = ref.watch(requestTypesProvider);
    final currenciesState = ref.watch(currenciesProvider);
    final selectedType = ref.watch(selectedRequestTypeProvider);

    final isLoadingRefs = typesState.isLoading || currenciesState.isLoading;
    final refsError = typesState.error ?? currenciesState.error;

    ref.listen<CreateRequestFormState>(createRequestFormProvider,
        (prev, next) {
      if (next.isSuccess && prev?.isSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (next.successMessage ?? 'Request submitted successfully')
                  .tr(context),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
      if (next.error != null && prev?.error != next.error) {
        GlobalErrorHandler.show(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'New request'.tr(context),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: isLoadingRefs
                ? const Center(child: LoadingIndicator())
                : refsError != null
                    ? ErrorFullScreen(
                        error: refsError,
                        onRetry: () {
                          ref.read(requestTypesProvider.notifier).load();
                          ref.read(currenciesProvider.notifier).load();
                        },
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Type
                              _buildTypeDropdown(
                                  context, form, notifier, typesState),
                              const SizedBox(height: 18),

                              // Subject
                              _buildSubjectField(context, form, notifier),
                              const SizedBox(height: 18),

                              // Amount + Currency (only when financial)
                              if (selectedType?.isFinancial == true) ...[
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildAmountField(
                                          context, form, notifier),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: _buildCurrencyDropdown(context,
                                          form, notifier, currenciesState),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                              ],

                              // Request date (optional)
                              _buildRequestDateField(context, form, notifier),
                              const SizedBox(height: 18),

                              // Description (optional)
                              _buildDescriptionField(context, form, notifier),
                              const SizedBox(height: 18),

                              // Attachment (optional / required depending on type)
                              _buildAttachmentField(
                                  context, form, notifier, selectedType),
                            ],
                          ),
                        ),
                      ),
          ),

          // Two buttons: Save Draft & Submit
          if (!isLoadingRefs && refsError == null)
            StickyBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: form.isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                notifier.submit(action: 'draft');
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primaryMid),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Save as draft'.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryMid,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Submit request'.tr(context),
                      loading: form.isLoading,
                      onTap: form.isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                notifier.submit(action: 'submit');
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Type ──────────────────────────────────────────────────────────

  Widget _buildTypeDropdown(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
    RequestTypesState typesState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Request type *'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: form.requestTypeId,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            errorText:
                form.fieldError('employee_request_type_id')?.tr(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          hint: Text(
            'Select request type'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: context.appColors.textMuted,
            ),
          ),
          validator: (v) =>
              v == null ? 'This field is required'.tr(context) : null,
          items: typesState.types.map((t) {
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            final label = isAr
                ? (t.nameAr.isNotEmpty ? t.nameAr : t.name)
                : (t.nameEn.isNotEmpty ? t.nameEn : t.name);
            return DropdownMenuItem<int>(
              value: t.id,
              child: Text(
                label,
                style:
                    const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) notifier.setRequestType(v);
          },
        ),
      ],
    );
  }

  // ── Subject ───────────────────────────────────────────────────────

  Widget _buildSubjectField(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject *'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            )),
        const SizedBox(height: 6),
        TextFormField(
          onChanged: notifier.setSubject,
          enabled: !form.isLoading,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'This field is required'.tr(context)
              : null,
          decoration: InputDecoration(
            errorText: form.fieldError('subject')?.tr(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Amount ────────────────────────────────────────────────────────

  Widget _buildAmountField(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${'Amount'.tr(context)} *',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            )),
        const SizedBox(height: 6),
        TextFormField(
          enabled: !form.isLoading,
          initialValue: form.amount?.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: (v) =>
              notifier.setAmount(v.isEmpty ? null : double.tryParse(v)),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n <= 0) {
              return 'Enter a valid positive number'.tr(context);
            }
            return null;
          },
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          decoration: InputDecoration(
            errorText: form.fieldError('amount')?.tr(context),
            hintText: 'Enter a positive amount'.tr(context),
            hintStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: context.appColors.textMuted,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Currency ──────────────────────────────────────────────────────

  Widget _buildCurrencyDropdown(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
    CurrenciesState currenciesState,
  ) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${'Currency'.tr(context)} *',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            )),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: form.currencyId,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            errorText: form.fieldError('currency_id')?.tr(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          hint: Text(
            'Select currency'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: context.appColors.textMuted,
            ),
          ),
          validator: (v) =>
              v == null ? 'This field is required'.tr(context) : null,
          selectedItemBuilder: (context) => currenciesState.currencies
              .map((c) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      c.code,
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          items: currenciesState.currencies
              .map((c) => DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(
                      '${isAr ? (c.nameAr ?? c.name) : (c.nameEn ?? c.name)} — ${c.code}',
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) notifier.setCurrency(v);
          },
        ),
      ],
    );
  }

  // ── Request date (optional) ───────────────────────────────────────

  Widget _buildRequestDateField(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Request date'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textSecondary,
                )),
            const SizedBox(width: 4),
            Text('(${'optional'.tr(context)})',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: context.appColors.textMuted,
                )),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickRequestDate(notifier),
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _requestDate != null
                        ? AppFuns.formatDate(_requestDate)
                        : 'Select date'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: _requestDate != null
                          ? context.appColors.textPrimary
                          : context.appColors.textMuted,
                      fontWeight: _requestDate != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(Icons.date_range_rounded,
                    size: 20, color: AppColors.primaryMid),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRequestDate(CreateRequestFormController notifier) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
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
      setState(() => _requestDate = picked);
      notifier.setRequestDate(_apiDateFormat.format(picked));
    }
  }

  // ── Description ───────────────────────────────────────────────────

  Widget _buildDescriptionField(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details (optional)'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            )),
        const SizedBox(height: 6),
        TextFormField(
          maxLines: 4,
          enabled: !form.isLoading,
          onChanged: notifier.setDescription,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          decoration: InputDecoration(
            errorText: form.fieldError('description')?.tr(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Attachment (optional / required depending on type) ───────────

  Widget _buildAttachmentField(
    BuildContext context,
    CreateRequestFormState form,
    CreateRequestFormController notifier,
    RequestType? selectedType,
  ) {
    final hasFile = form.attachmentPath != null;
    final fileName = form.attachmentName ?? '';
    final apiError = form.fieldError('file')?.tr(context);
    final isRequired = selectedType?.requiresAttachment == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Attachment'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textSecondary,
                )),
            const SizedBox(width: 4),
            if (isRequired)
              const Text(' *',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ))
            else
              Text('(${'optional'.tr(context)})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  )),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickFile(notifier),
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              errorText: apiError,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file_rounded,
                    size: 20, color: AppColors.primaryMid),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasFile ? fileName : 'Tap to choose a file'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: hasFile
                          ? context.appColors.textPrimary
                          : context.appColors.textMuted,
                      fontWeight:
                          hasFile ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasFile)
                  GestureDetector(
                    onTap: () => notifier.clearAttachment(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (isRequired)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'This request type requires an attachment'.tr(context),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        Text(
          'Allowed: PDF, JPG, JPEG, PNG, ZIP — max 10 MB'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(CreateRequestFormController notifier) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final path = picked.path;
      if (path == null) return;

      final sizeMb = File(path).lengthSync() / (1024 * 1024);
      if (sizeMb > _maxFileSizeMb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File exceeds 10 MB'.tr(context),
                  style: const TextStyle(fontFamily: 'Cairo')),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      notifier.setAttachment(path, picked.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo')),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}
