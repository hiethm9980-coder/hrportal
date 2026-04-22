import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import '../../../../data/models/activity_models.dart';
import '../../../providers/activity_provider.dart';

/// "Activity" tab of the task detail screen.
///
/// A unified timeline of everything that has happened to the task:
///   - Status changes — rendered as tall cards with from→to pills, the
///     duration the task spent in the previous status, and the actor.
///   - Updates — one-line rows: icon + localized title + actor + time.
///
/// Items are grouped by local-timezone day (Today / Yesterday / full date)
/// and ordered newest-first exactly as the server returns them.
class ActivityTab extends ConsumerStatefulWidget {
  final int taskId;
  final String? initialTitle;

  const ActivityTab({
    super.key,
    required this.taskId,
    this.initialTitle,
  });

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityProvider(widget.taskId).notifier).load();
    });
  }

  Future<void> _refresh() async {
    await ref.read(activityProvider(widget.taskId).notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityProvider(widget.taskId));
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _Header(
            parentTitle: widget.initialTitle ?? '',
            total: state.summary.total,
            updatesCount: state.summary.updatesCount,
            statusChangesCount: state.summary.statusChangesCount,
            onBack: () => Navigator.of(context).maybePop(),
            onRefresh: _refresh,
          ),
          Expanded(
            child: Container(
              color: colors.bg,
              child: state.isLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null && state.items.isEmpty
                      ? _ErrorView(
                          message: state.error!,
                          onRetry: _refresh,
                        )
                      : state.items.isEmpty
                          ? const _EmptyView()
                          : _ActivityList(
                              items: state.items,
                              onRefresh: _refresh,
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String parentTitle;
  final int total;
  final int updatesCount;
  final int statusChangesCount;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _Header({
    required this.parentTitle,
    required this.total,
    required this.updatesCount,
    required this.statusChangesCount,
    required this.onBack,
    required this.onRefresh,
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
          // Row layout — written in natural start→end order; Flutter
          // auto-flips for RTL, putting the back button on the right and
          // the actions on the left (matches the Comments / Attachments
          // header convention).
          Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Activity'.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (total > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              AppFuns.replaceArabicNumbers('$total'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
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
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),
          // Summary chips — quick overview of what's in the feed without
          // having to scan it.
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    icon: Icons.history_rounded,
                    label: 'Status changes'.tr(context),
                    count: statusChangesCount,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryChip(
                    icon: Icons.update_rounded,
                    label: 'Updates'.tr(context),
                    count: updatesCount,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppFuns.replaceArabicNumbers('$count'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// List + date grouping
// ═══════════════════════════════════════════════════════════════════

sealed class _Row {
  const _Row();
}

class _DayHeader extends _Row {
  final DateTime day;
  const _DayHeader(this.day);
}

class _ItemRow extends _Row {
  final ActivityItem item;
  const _ItemRow(this.item);
}

class _ActivityList extends StatelessWidget {
  final List<ActivityItem> items;
  final Future<void> Function() onRefresh;

  const _ActivityList({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final rows = _groupByDay(items);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          if (r is _DayHeader) return _DayDivider(day: r.day);
          final item = (r as _ItemRow).item;
          return item.kind == ActivityKind.statusChange
              ? _StatusChangeCard(
                  key: ValueKey('act-${item.id}'),
                  item: item,
                )
              : _UpdateCard(
                  key: ValueKey('act-${item.id}'),
                  item: item,
                );
        },
      ),
    );
  }

  /// Walk the chronological list and insert a day header when the local
  /// date changes. Works identically for newest→oldest and oldest→newest
  /// input orders since we only care about transitions, not direction.
  List<_Row> _groupByDay(List<ActivityItem> sorted) {
    final out = <_Row>[];
    DateTime? lastDay;
    for (final it in sorted) {
      final created = it.createdAt;
      if (created == null) {
        out.add(_ItemRow(it));
        continue;
      }
      final local = created.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || day != lastDay) {
        out.add(_DayHeader(day));
        lastDay = day;
      }
      out.add(_ItemRow(it));
    }
    return out;
  }
}

class _DayDivider extends StatelessWidget {
  final DateTime day;
  const _DayDivider({required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: colors.gray100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _formatDayLabel(context, day),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Status-change card
// ═══════════════════════════════════════════════════════════════════

class _StatusChangeCard extends StatelessWidget {
  final ActivityItem item;
  const _StatusChangeCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sc = item.statusChange;
    final actor = item.actor?.name ?? 'System'.tr(context);
    final time = item.createdAt == null
        ? ''
        : AppFuns.formatTime(item.createdAt!.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryMid.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.sync_alt_rounded,
                  size: 16,
                  color: AppColors.primaryMid,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title.isNotEmpty
                      ? item.title
                      : 'Status changed'.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (sc != null) ...[
            const SizedBox(height: 10),
            // from → to pills. Flutter's Row auto-flips for RTL, and
            // `arrow_forward_rounded` auto-mirrors, so the arrow always
            // points *from* the old status *to* the new one regardless
            // of language direction.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (sc.from != null) _StatusPill(chip: sc.from!),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: colors.textMuted,
                ),
                if (sc.to != null) _StatusPill(chip: sc.to!),
                if ((sc.durationLabel ?? '').isNotEmpty)
                  _DurationPill(label: sc.durationLabel!),
              ],
            ),
            if ((sc.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sc.notes!,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          _ActorLine(name: actor, time: time),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ActivityStatusChip chip;
  const _StatusPill({required this.chip});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(chip.color ?? '#9E9E9E');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            chip.label ?? chip.code ?? '—',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  final String label;
  const _DurationPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryMid.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 11,
            color: AppColors.primaryMid,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryMid,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Update card (one-line audit entry)
// ═══════════════════════════════════════════════════════════════════

class _UpdateCard extends StatelessWidget {
  final ActivityItem item;
  const _UpdateCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (icon, color) = _iconForType(item.type);
    final title = _localizedTitle(context, item);
    final actor = item.actor?.name ?? 'System'.tr(context);
    final time = item.createdAt == null
        ? ''
        : AppFuns.formatTime(item.createdAt!.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _ActorLine(name: actor, time: time),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorLine extends StatelessWidget {
  final String name;
  final String time;
  const _ActorLine({required this.name, required this.time});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      time.isEmpty ? name : '$name  ·  $time',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty / error
// ═══════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 56, color: colors.textDisabled),
            const SizedBox(height: 10),
            Text(
              'No activity'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No activity has been recorded on this task yet'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
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
            Icon(Icons.error_outline_rounded,
                size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry'.tr(context)),
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

/// Icon + color for each audit-log update type. Falls back to a neutral
/// info icon for types we don't know yet so the UI never renders a blank
/// leading cell.
(IconData, Color) _iconForType(String type) {
  switch (type) {
    case 'comment_added':
      return (Icons.chat_bubble_outline_rounded, const Color(0xFF3B82F6));
    case 'attachment_uploaded':
      return (Icons.attach_file_rounded, const Color(0xFF10B981));
    case 'attachment_deleted':
      return (
        Icons.delete_outline_rounded,
        const Color(0xFFEF4444),
      );
    case 'time_logged':
      return (Icons.timer_outlined, const Color(0xFFF59E0B));
    case 'subtask_created':
      return (Icons.account_tree_rounded, const Color(0xFF7C3AED));
    case 'task_updated':
      return (Icons.edit_rounded, const Color(0xFF0EA5E9));
    case 'progress_updated':
      return (Icons.trending_up_rounded, const Color(0xFF10B981));
    case 'task_completion_rejected':
      return (Icons.cancel_outlined, const Color(0xFFEF4444));
    case 'task_completion_approved':
      return (Icons.check_circle_outline_rounded, const Color(0xFF10B981));
    case 'status_changed':
      return (Icons.sync_alt_rounded, AppColors.primaryMid);
    default:
      return (Icons.info_outline_rounded, const Color(0xFF64748B));
  }
}

/// Prefer the server's localized title; fall back to a client-side i18n
/// key for safety if the server ever returns an empty string.
String _localizedTitle(BuildContext context, ActivityItem it) {
  if (it.title.trim().isNotEmpty) return it.title;
  switch (it.type) {
    case 'comment_added':
      return 'Comment added'.tr(context);
    case 'attachment_uploaded':
      return 'Attachment uploaded'.tr(context);
    case 'attachment_deleted':
      return 'Attachment deleted'.tr(context);
    case 'time_logged':
      return 'Time logged'.tr(context);
    case 'subtask_created':
      return 'Subtask created'.tr(context);
    case 'task_updated':
      return 'Task updated'.tr(context);
    case 'progress_updated':
      return 'Progress updated'.tr(context);
    case 'task_completion_rejected':
      return 'Completion rejected'.tr(context);
    case 'task_completion_approved':
      return 'Completion approved'.tr(context);
    case 'status_changed':
      return 'Status changed'.tr(context);
    default:
      return it.type;
  }
}

String _formatDayLabel(BuildContext context, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today'.tr(context);
  if (day == yesterday) return 'Yesterday'.tr(context);
  return AppFuns.formatDate(day);
}

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}
