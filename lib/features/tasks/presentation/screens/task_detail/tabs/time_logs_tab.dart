import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../../data/models/time_log_models.dart';
import '../../../providers/time_logs_provider.dart';
import 'time_log_add_sheet.dart';

/// "Time" tab of the task detail screen.
///
/// Three-row header (back + title + search/refresh · status chips · total
/// hours) sits above a vertically scrolling list of [_TimeLogCard]s.
/// A FAB becomes visible only when the server says `can_add_time_log=true`.
class TimeLogsTab extends ConsumerStatefulWidget {
  final int taskId;
  final String? initialTitle;

  const TimeLogsTab({
    super.key,
    required this.taskId,
    this.initialTitle,
  });

  @override
  ConsumerState<TimeLogsTab> createState() => _TimeLogsTabState();
}

class _TimeLogsTabState extends ConsumerState<TimeLogsTab> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;

  // ── Add-time-log sheet ────────────────────────────────────────────
  // Rendered as an in-tree overlay inside this tab's Stack (NOT via
  // `showModalBottomSheet`) so the task-detail shell's bottom navigation
  // bar stays visible above it. `_sheetOpenCount` is used as a ValueKey
  // so each open cycle gives the sheet a fresh State (clean form).
  bool _showAddSheet = false;
  int _sheetOpenCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(timeLogsProvider(widget.taskId).notifier).load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      ref.read(timeLogsProvider(widget.taskId).notifier).setSearch(v);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(timeLogsProvider(widget.taskId).notifier).setSearch('');
  }

  void _toggleSearch() => setState(() => _showSearch = !_showSearch);

  Future<void> _refresh() async {
    _searchController.clear();
    final n = ref.read(timeLogsProvider(widget.taskId).notifier)
      ..setStatus('all');
    await n.load();
  }

  void _openAddSheet() {
    // Dismiss keyboard if search was focused — otherwise the sheet slides
    // up with the keyboard hiding half of it.
    FocusScope.of(context).unfocus();
    setState(() {
      _sheetOpenCount++;
      _showAddSheet = true;
    });
  }

  void _closeAddSheet() {
    FocusScope.of(context).unfocus();
    setState(() => _showAddSheet = false);
  }

  void _handleSheetCreated() {
    FocusScope.of(context).unfocus();
    setState(() => _showAddSheet = false);
    // The controller already reloaded the list inside createLog() — just
    // confirm the save to the user.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Time log created successfully'.tr(context),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDelete(TimeLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete time log'.tr(ctx),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete this time log?'.tr(ctx),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr(ctx),
                style: const TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr(ctx),
                style: const TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(timeLogsProvider(widget.taskId).notifier)
          .deleteLog(log.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Time log deleted successfully'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timeLogsProvider(widget.taskId));

    return Stack(
      children: [
        Column(
          children: [
            _TimeLogsHeader(
              parentTitle: widget.initialTitle ?? '',
              searchActive: state.filter.q.trim().isNotEmpty,
              showSearch: _showSearch,
              searchController: _searchController,
              breakdown: state.statusBreakdown,
              selectedCode: state.filter.statusCode,
              totalHours: state.summary.totalHours,
              onBack: () => Navigator.of(context).maybePop(),
              onToggleSearch: _toggleSearch,
              onClearSearch: _clearSearch,
              onSearchChanged: _onSearchChanged,
              onRefresh: _refresh,
              onStatusChipTap: (code) => ref
                  .read(timeLogsProvider(widget.taskId).notifier)
                  .setStatus(code),
            ),
            Expanded(
              child: _Body(
                state: state,
                onRefresh: () =>
                    ref.read(timeLogsProvider(widget.taskId).notifier).load(),
                onDelete: _confirmDelete,
              ),
            ),
          ],
        ),
        if (state.isMutating)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              ),
            ),
          ),
        if (state.summary.canAddTimeLog)
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton(
              heroTag: 'time-log-fab-${widget.taskId}',
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
              onPressed: _openAddSheet,
              child: const Icon(Icons.add_rounded),
            ),
          ),

        // ── Add-time-log overlay ────────────────────────────────────
        // Built INSIDE this tab's Stack (not via `showModalBottomSheet`)
        // so it stays above the tab body but below the shell's bottom
        // navigation bar, which remains visible while the sheet is open.
        if (state.summary.canAddTimeLog)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showAddSheet,
              child: Stack(
                children: [
                  // Dimmed backdrop — tap to dismiss.
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showAddSheet ? 1 : 0,
                      child: GestureDetector(
                        onTap: _closeAddSheet,
                        behavior: HitTestBehavior.opaque,
                        child: const ColoredBox(color: Colors.black54),
                      ),
                    ),
                  ),
                  // Sheet — slides up from the bottom of this tab's body.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      offset: _showAddSheet
                          ? Offset.zero
                          : const Offset(0, 1),
                      child: TimeLogAddSheet(
                        key: ValueKey(_sheetOpenCount),
                        taskId: widget.taskId,
                        onClose: _closeAddSheet,
                        onCreated: _handleSheetCreated,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header — 3 rows (back+title / chips / total-hours).
// ═══════════════════════════════════════════════════════════════════

class _TimeLogsHeader extends StatelessWidget {
  final String parentTitle;
  final bool searchActive;
  final bool showSearch;
  final TextEditingController searchController;
  final TimeLogStatusBreakdown breakdown;
  final String selectedCode;
  final double totalHours;

  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final ValueChanged<String> onStatusChipTap;

  const _TimeLogsHeader({
    required this.parentTitle,
    required this.searchActive,
    required this.showSearch,
    required this.searchController,
    required this.breakdown,
    required this.selectedCode,
    required this.totalHours,
    required this.onBack,
    required this.onToggleSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onStatusChipTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 14,
        right: 14,
      ),
      child: Column(
        children: [
          // ── Row 1: back · title/subtitle · search · refresh ──────
          Row(
            children: [
              _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Time'.tr(context),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (parentTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          parentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _IconBtn(
                icon: showSearch
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.search_rounded,
                active: !showSearch && searchActive,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),

          // Animated search field (shared look with other tabs).
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: showSearch
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _SearchField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      onClear: onClearSearch,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // ── Row 2: status chips ─────────────────────────────────
          _StatusChipsRow(
            breakdown: breakdown,
            selectedCode: selectedCode,
            onTap: onStatusChipTap,
          ),

          const SizedBox(height: 10),

          // ── Row 3: total hours ──────────────────────────────────
          _TotalHoursRow(totalHours: totalHours),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Row 2 — status chips. Mirrors the task-list chips but adapted for the
// time-log breakdown shape (code + label + color + count + hours).
// ═══════════════════════════════════════════════════════════════════

class _StatusChipsRow extends StatelessWidget {
  final TimeLogStatusBreakdown breakdown;
  final String selectedCode;
  final ValueChanged<String> onTap;

  const _StatusChipsRow({
    required this.breakdown,
    required this.selectedCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If the server returns no chips (e.g., before first load), fall back to
    // a static "All" chip so the row never disappears and the user can at
    // least trigger a reload by tapping it.
    final chips = breakdown.statuses.isNotEmpty
        ? breakdown.statuses
        : const [
            TimeLogStatusEntry(
              code: 'all',
              label: 'All',
              color: '#3B82F6',
              count: 0,
              hours: 0,
            ),
          ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          return _Chip(
            // Server-provided labels are already localized; keep them.
            label: c.label,
            count: c.count,
            color: _parseHex(c.color),
            selected: c.code == selectedCode,
            onTap: () => onTap(c.code),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.55)
                : Colors.white.withOpacity(0.10),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Row 3 — "Total hours" label on one side and the server total on the
// other. Fully reactive to filters (the backend recomputes it).
// ═══════════════════════════════════════════════════════════════════

class _TotalHoursRow extends StatelessWidget {
  final double totalHours;
  const _TotalHoursRow({required this.totalHours});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Total hours'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
          Text(
            _formatHours(totalHours),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Body — list of time log cards, with loading / empty / error states.
// ═══════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  final TimeLogsState state;
  final Future<void> Function() onRefresh;
  final void Function(TimeLog log) onDelete;

  const _Body({
    required this.state,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.logs.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.error != null && state.logs.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRefresh);
    }
    if (state.logs.isEmpty) {
      return _EmptyView(
        hasFilters: state.filter.q.isNotEmpty || state.filter.statusCode != 'all',
        onRetry: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 92),
        itemCount: state.logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final log = state.logs[i];
          return _TimeLogCard(log: log, onDelete: () => onDelete(log));
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Time log card — compact, shows:
//   - Description (title)
//   - Range label (date or date → date)
//   - Employee name
//   - Hours spent (right-side pill)
//   - Status chip (in_range / overdue / upcoming)
//   - Trash icon ONLY when log.canDelete is true
// ═══════════════════════════════════════════════════════════════════

class _TimeLogCard extends StatelessWidget {
  final TimeLog log;
  final VoidCallback onDelete;

  const _TimeLogCard({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = log.status != null
        ? _parseHex(log.status!.color)
        : colors.gray400;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row A — status chip on the left, hours pill on the right, trash
          // icon (if allowed) between them.
          Row(
            children: [
              if (log.status != null)
                _StatusBadge(status: log.status!)
              else
                const SizedBox.shrink(),
              const Spacer(),
              if (log.canDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  tooltip: 'Delete'.tr(context),
                ),
              _HoursPill(hours: log.hoursSpent, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          // Row B — description (fallback to "—" when empty so the layout
          // doesn't collapse).
          Text(
            (log.description?.trim().isNotEmpty ?? false)
                ? log.description!.trim()
                : '—',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          // Row C — range + employee with matching icons for scannability.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _MetaItem(
                icon: Icons.event_rounded,
                text: log.rangeLabel,
                color: colors.textSecondary,
              ),
              if (log.employee != null)
                _MetaItem(
                  icon: Icons.person_outline_rounded,
                  text: log.employee!.name,
                  color: colors.textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TimeLogStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(status.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursPill extends StatelessWidget {
  final double hours;
  final Color color;

  const _HoursPill({required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _formatHours(hours),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetaItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared small widgets — search field, icon button, empty / error views.
// ═══════════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextFormField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 14,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Search time logs...'.tr(context),
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              suffixIcon: hasText
                  ? GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, left: 4),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          );
        },
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final Future<void> Function() onRetry;
  const _EmptyView({required this.hasFilters, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        children: [
          Icon(Icons.schedule_rounded, size: 64, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No time logs'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try different filters'.tr(context)
                : 'No time has been logged on this task yet'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryMid,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}

/// Formats hours as `2h`, `2.5h`, `0.25h` — trims trailing zeros so
/// whole-hour values stay visually clean.
String _formatHours(double hours) {
  if (hours == hours.roundToDouble()) {
    return '${hours.toInt()}h';
  }
  final rounded = (hours * 100).round() / 100.0;
  final text = rounded.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return '${text}h';
}
