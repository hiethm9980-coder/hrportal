import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'tabs/activity_tab.dart';
import 'tabs/attachments_tab.dart';
import 'tabs/comments_tab.dart';
import 'tabs/details_tab.dart';
import 'tabs/subtasks_tab.dart';
import 'tabs/time_logs_tab.dart';

/// The six tabs exposed by the task detail screen.
///
/// [subtasks], [time] and [comments] are fully implemented; the other three
/// render a placeholder until they're built.
enum TaskDetailTab {
  subtasks,
  time,
  comments,
  attachments,
  activity,
  details,
}

/// Wraps every task detail tab behind a shared bottom nav.
///
/// Each tab is responsible for its own header so it can tailor the controls
/// (status dropdown + progress on Subtasks, timer on Time, composer on
/// Comments, etc.). The shell only owns the bottom navigation bar.
class TaskDetailShell extends StatefulWidget {
  /// The id of the task being viewed. Passed down to every tab so they can
  /// fetch their slice of data.
  final int taskId;

  /// Optional task title to show in each tab's header while the full payload
  /// is still loading. Helps avoid a flash of "…" on initial open when we
  /// navigate from a card that already knows the title.
  final String? initialTitle;

  /// Which tab to show first — used by internal navigation (e.g. tapping a
  /// task card from My Tasks). Defaults to [TaskDetailTab.subtasks].
  final TaskDetailTab initialTab;

  /// Deep-link tab identifier from the `?tab=<name>` query param in
  /// notification routes. When set (and matches one of the known names)
  /// it takes precedence over [initialTab]. Supported values:
  ///
  ///   details · subtasks · time-logs · comments · attachments · activity
  ///
  /// Any unknown / null value falls through to [initialTab]. Kept as a
  /// `String?` (not an enum) so the router can forward the raw query
  /// value without having to know the enum layout.
  final String? initialTabName;

  const TaskDetailShell({
    super.key,
    required this.taskId,
    this.initialTitle,
    this.initialTab = TaskDetailTab.subtasks,
    this.initialTabName,
  });

  @override
  State<TaskDetailShell> createState() => _TaskDetailShellState();
}

class _TaskDetailShellState extends State<TaskDetailShell> {
  late TaskDetailTab _tab;

  @override
  void initState() {
    super.initState();
    // Deep-link tab name wins if present; otherwise fall back to the
    // caller-provided enum (or the shell's own default).
    _tab = _tabFromName(widget.initialTabName) ?? widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant TaskDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If GoRouter rebuilds the widget with a new `?tab=` query param —
    // e.g. a second notification for the same task arrives while the
    // screen is already open — switch the visible tab to match.
    if (widget.initialTabName != oldWidget.initialTabName) {
      final next = _tabFromName(widget.initialTabName);
      if (next != null && next != _tab) {
        setState(() => _tab = next);
      }
    }
  }

  /// Map the backend-issued deep-link slug to our tab enum. Returns
  /// `null` for unknown / missing names so the caller can fall back.
  ///
  /// Keep in sync with the backend notification dispatcher: see
  /// `TaskNotificationService.php`'s route builder.
  static TaskDetailTab? _tabFromName(String? name) {
    switch (name?.trim().toLowerCase()) {
      case 'details':
        return TaskDetailTab.details;
      case 'subtasks':
        return TaskDetailTab.subtasks;
      // Backend emits `time-logs` (dashed) — our enum value is `time`
      // (picked when the tab was originally built). Map both for safety.
      case 'time-logs':
      case 'time':
        return TaskDetailTab.time;
      case 'comments':
        return TaskDetailTab.comments;
      case 'attachments':
        return TaskDetailTab.attachments;
      case 'activity':
        return TaskDetailTab.activity;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: _buildTab(),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onChanged: (t) => setState(() => _tab = t),
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case TaskDetailTab.subtasks:
        return SubtasksTab(
          taskId: widget.taskId,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.time:
        return TimeLogsTab(
          taskId: widget.taskId,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.comments:
        return CommentsTab(
          taskId: widget.taskId,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.attachments:
        return AttachmentsTab(
          taskId: widget.taskId,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.activity:
        return ActivityTab(
          taskId: widget.taskId,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.details:
        return DetailsTab(
          taskId: widget.taskId,
          initialTitle: widget.initialTitle,
          // Let the Details tab jump to sibling tabs when the user taps
          // a counter (subtasks / comments / attachments / time logs).
          // The shell is the only thing that knows which tab is active,
          // so it must own `setState` — we just pass down a closure.
          onNavigateToTab: (t) => setState(() => _tab = t),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bottom navigation
// ═══════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final TaskDetailTab current;
  final ValueChanged<TaskDetailTab> onChanged;

  const _BottomNav({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(top: BorderSide(color: colors.gray100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _NavItem(
                icon: '🧩',
                label: 'Subtasks'.tr(context),
                active: current == TaskDetailTab.subtasks,
                onTap: () => onChanged(TaskDetailTab.subtasks),
              ),
              _NavItem(
                icon: '⏱',
                label: 'Time'.tr(context),
                active: current == TaskDetailTab.time,
                onTap: () => onChanged(TaskDetailTab.time),
              ),
              _NavItem(
                icon: '💬',
                label: 'Comments'.tr(context),
                active: current == TaskDetailTab.comments,
                onTap: () => onChanged(TaskDetailTab.comments),
              ),
              _NavItem(
                icon: '📎',
                label: 'Attachments'.tr(context),
                active: current == TaskDetailTab.attachments,
                onTap: () => onChanged(TaskDetailTab.attachments),
              ),
              _NavItem(
                icon: '📊',
                label: 'Activity'.tr(context),
                active: current == TaskDetailTab.activity,
                onTap: () => onChanged(TaskDetailTab.activity),
              ),
              _NavItem(
                icon: '📋',
                label: 'Details'.tr(context),
                active: current == TaskDetailTab.details,
                onTap: () => onChanged(TaskDetailTab.details),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mirrors the bottom-nav item style used on the main shell
/// (see `app_router.dart` `_NavItem`): emoji + label + underline indicator.
/// Kept as a separate widget because the task detail shell carries 6 tabs
/// instead of 5–6 and we want full control over sizing on narrower screens.
class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? AppColors.primaryMid : colors.gray400,
                ),
              ),
              if (active)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// All six tabs now have real implementations — the `_PlaceholderTab`
// "coming soon" widget that used to live here is no longer needed and
// has been removed. Attachments, Activity, and Details each own a full
// screen now; see their respective files under `tabs/`.
