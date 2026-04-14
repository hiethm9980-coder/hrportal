import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import '../../data/models/task_models.dart';
import '../../data/models/task_status_model.dart';

/// Callback signature for commiting a new progress value to the server.
/// Returns a future so the card can show a small loading indicator while
/// the request is in flight. [previousPercent] lets callers roll back on
/// failure.
typedef ProgressCommit = Future<void> Function({
  required int taskId,
  required int percent,
  required int previousPercent,
});

/// Renders a single task as a card.
///
/// - Top row: priority badge + task code (optional) + project name + overdue flag.
/// - Title + (optional) description.
/// - Bottom: horizontally-scrollable row of status chips. Tapping a chip
///   triggers [onStatusChange] (which the parent debounces / confirms). The
///   chip matching the task's current status is highlighted.
class TaskCard extends StatelessWidget {
  final Task task;
  final List<TaskStatus> allStatuses;
  final VoidCallback? onTap;
  final ValueChanged<TaskStatus> onStatusChange;
  final ProgressCommit? onProgressChange;

  const TaskCard({
    super.key,
    required this.task,
    required this.allStatuses,
    required this.onStatusChange,
    this.onTap,
    this.onProgressChange,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentStatusCode = task.status?.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
        border: Border.all(color: colors.cardBorder, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Body: tapping here opens the task details screen. ──────
          // The status row below is *outside* this InkWell so tapping a
          // status chip never bubbles up as a "card tap".
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row + external-link "open" icon at far end.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _TopRow(task: task)),
                        const SizedBox(width: 6),
                        _OpenIconBox(onTap: onTap),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    if ((task.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                    if (task.assignee != null) ...[
                      const SizedBox(height: 8),
                      _AssigneeRow(name: task.assignee!.name),
                    ],
                    // Counters row: subtasks / attachments / comments /
                    // time logs / due date.
                    const SizedBox(height: 10),
                    _CountersRow(task: task),
                  ],
                ),
              ),
            ),
          ),
          // ── Progress slider: independent tap target (dragging or tapping
          // here must NEVER open the task details screen). ───────────────
          if (task.progressPercent != null && onProgressChange != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _ProgressSlider(
                taskId: task.id,
                initialPercent: task.progressPercent!,
                onCommit: onProgressChange!,
              ),
            )
          else if (task.progressPercent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _ProgressBar(percent: task.progressPercent!),
            ),
          // ── Status chips: independent tap target. ──────────────────
          if (allStatuses.isNotEmpty) ...[
            Divider(height: 1, thickness: 0.5, color: colors.gray200),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: _StatusRow(
                statuses: allStatuses,
                currentCode: currentStatusCode,
                onTap: onStatusChange,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════

class _TopRow extends StatelessWidget {
  final Task task;
  const _TopRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final priority = task.priority;
    final project = task.project;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (priority != null) ...[
          _Pill(
            label: _priorityLabel(context, priority.code, priority.label),
            color: _parseHex(priority.color),
            icon: _priorityIcon(priority.code),
          ),
          const SizedBox(width: 8),
        ],
        if (task.code != null && task.code!.isNotEmpty) ...[
          Text(
            task.code!,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (project != null)
          Expanded(
            child: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryMid,
              ),
            ),
          )
        else
          const Spacer(),
        if (task.isOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: AppColors.error,
                ),
                const SizedBox(width: 3),
                Text(
                  'Overdue'.tr(context),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Row showing the task's assignee — small avatar circle + name.
class _AssigneeRow extends StatelessWidget {
  final String name;
  const _AssigneeRow({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primaryMid.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 14,
            color: AppColors.primaryMid,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final List<TaskStatus> statuses;
  final String? currentCode;
  final ValueChanged<TaskStatus> onTap;

  const _StatusRow({
    required this.statuses,
    required this.currentCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = statuses[i];
          final isActive = s.code == currentCode;
          final color = _parseHex(s.color);
          return GestureDetector(
            onTap: () => onTap(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color : color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? color : color.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) ...[
                    const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    s.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
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

IconData? _priorityIcon(String code) {
  switch (code.toUpperCase()) {
    case 'CRITICAL':
      return Icons.local_fire_department_rounded;
    case 'HIGH':
      return Icons.priority_high_rounded;
    case 'MEDIUM':
      return Icons.drag_handle_rounded;
    case 'LOW':
      return Icons.arrow_downward_rounded;
    default:
      return null;
  }
}

/// Returns the canonical translated label for a priority [code]
/// (e.g. `HIGH` → "عالي" / "High"). Falls back to the server-sent
/// [serverLabel] if the code is not one of the known four.
String _priorityLabel(
  BuildContext context,
  String code,
  String serverLabel,
) {
  switch (code.toUpperCase()) {
    case 'LOW':
      return 'Low'.tr(context);
    case 'MEDIUM':
      return 'Medium'.tr(context);
    case 'HIGH':
      return 'High'.tr(context);
    case 'CRITICAL':
      return 'Critical'.tr(context);
    default:
      return serverLabel;
  }
}

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}

// ═══════════════════════════════════════════════════════════════════
// Open-details icon (top-right square button)
// ═══════════════════════════════════════════════════════════════════

class _OpenIconBox extends StatelessWidget {
  final VoidCallback? onTap;
  const _OpenIconBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: colors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.gray200, width: 0.8),
        ),
        child: Icon(
          Icons.open_in_new_rounded,
          size: 14,
          color: AppColors.primaryMid,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Interactive progress slider — drag to update, commit on release.
// ═══════════════════════════════════════════════════════════════════

class _ProgressSlider extends StatefulWidget {
  final int taskId;
  final int initialPercent;
  final ProgressCommit onCommit;

  const _ProgressSlider({
    required this.taskId,
    required this.initialPercent,
    required this.onCommit,
  });

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider> {
  /// The value currently shown on the slider. Updated on every drag tick
  /// (so the thumb follows the finger) but only sent to the server on
  /// [Slider.onChangeEnd].
  late double _value;

  /// What was on the slider before the current drag started — used for
  /// rollback if the server call fails.
  late int _committedPercent;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialPercent.toDouble();
    _committedPercent = widget.initialPercent;
  }

  @override
  void didUpdateWidget(covariant _ProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from the outside (e.g. list reload) ONLY when we're not in
    // the middle of a save, and the external value actually differs.
    if (!_isSaving && widget.initialPercent != _committedPercent) {
      setState(() {
        _value = widget.initialPercent.toDouble();
        _committedPercent = widget.initialPercent;
      });
    }
  }

  Future<void> _commit(double newValue) async {
    final newPercent = newValue.round().clamp(0, 100);
    if (newPercent == _committedPercent) return; // no-op
    final previous = _committedPercent;
    setState(() {
      _isSaving = true;
      _committedPercent = newPercent;
    });
    try {
      await widget.onCommit(
        taskId: widget.taskId,
        percent: newPercent,
        previousPercent: previous,
      );
    } catch (_) {
      // Rollback visible value — the provider already rolled back its
      // state, but the slider holds its own local value.
      if (mounted) {
        setState(() {
          _value = previous.toDouble();
          _committedPercent = previous;
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final percent = _value.round();
    final barColor = _barColorFor(percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: barColor,
                ),
              ),
            ),
            const Spacer(),
            if (_isSaving)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                'Progress'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: colors.textMuted,
                ),
              ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: barColor,
            inactiveTrackColor: colors.gray100,
            thumbColor: barColor,
            overlayColor: barColor.withOpacity(0.14),
          ),
          child: Slider(
            value: _value.clamp(0, 100),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: _isSaving
                ? null
                : (v) => setState(() => _value = v),
            onChangeEnd: _isSaving ? null : _commit,
          ),
        ),
      ],
    );
  }

  /// Color scale — same as read-only [_ProgressBar] so both look identical
  /// when progress is non-editable.
  Color _barColorFor(int percent) {
    if (percent >= 80) return AppColors.success;
    if (percent >= 40) return AppColors.gold;
    return AppColors.error;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Progress bar (read-only fallback when no edit callback is provided)
// ═══════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final int percent; // 0..100
  const _ProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final clamped = percent.clamp(0, 100);
    final barColor = _barColorFor(clamped);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$clamped%',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: barColor,
              ),
            ),
            const Spacer(),
            Text(
              'Progress'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: clamped / 100.0,
            minHeight: 6,
            backgroundColor: colors.gray100,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  /// Color scale: red → amber → green as progress increases. Keeps the
  /// card scannable at a glance.
  Color _barColorFor(int percent) {
    if (percent >= 80) return AppColors.success;
    if (percent >= 40) return AppColors.gold;
    return AppColors.error;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Counters row (subtasks / comments / attachments / time logs / due)
// ═══════════════════════════════════════════════════════════════════

class _CountersRow extends StatelessWidget {
  final Task task;
  const _CountersRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final items = <Widget>[];

    if (task.subtasksTotal > 0) {
      items.add(_Counter(
        icon: Icons.account_tree_outlined,
        text: '${task.subtasksDone}/${task.subtasksTotal}',
      ));
    }
    if ((task.attachmentsCount ?? 0) > 0) {
      items.add(_Counter(
        icon: Icons.attach_file_rounded,
        text: '${task.attachmentsCount}',
      ));
    }
    if ((task.commentsCount ?? 0) > 0) {
      items.add(_Counter(
        icon: Icons.chat_bubble_outline_rounded,
        text: '${task.commentsCount}',
      ));
    }
    if ((task.timeLogsCount ?? 0) > 0) {
      items.add(_Counter(
        icon: Icons.schedule_outlined,
        text: task.timeLogsHours != null && task.timeLogsHours! > 0
            ? '${_fmtHours(task.timeLogsHours!)}h'
            : '${task.timeLogsCount}',
      ));
    }

    // Due date anchored to the END of the row.
    final dueWidget = (task.dueDate ?? '').isNotEmpty
        ? _Counter(
            icon: Icons.event_outlined,
            text: task.dueDate!,
          )
        : null;

    if (items.isEmpty && dueWidget == null) {
      return const SizedBox.shrink();
    }

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11,
        color: colors.textMuted,
      ),
      child: Row(
        children: [
          ...items.expand((w) => [w, const SizedBox(width: 10)]),
          const Spacer(),
          if (dueWidget != null) dueWidget,
        ],
      ),
    );
  }

  String _fmtHours(double h) {
    if (h == h.roundToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1);
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Counter({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
