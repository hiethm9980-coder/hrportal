import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'tabs/comments_tab.dart';
import 'tabs/time_logs_tab.dart';

/// The five tabs exposed by the task detail screen.
///
/// The legacy "Subtasks" tab has been retired: with the flat-list backend,
/// every task (root or subtask, at any depth) shows up directly in the user's
/// "My Tasks" list, so a per-task subtasks browser is no longer needed.
///
/// [time] and [comments] are fully implemented; the other three render a
/// placeholder until they're built.
enum TaskDetailTab {
  time,
  comments,
  attachments,
  activity,
  details,
}

/// Wraps every task detail tab behind a shared bottom nav.
///
/// Each tab is responsible for its own header so it can tailor the controls
/// (timer on Time, composer on Comments, etc.). The shell only owns the
/// bottom navigation bar.
class TaskDetailShell extends StatefulWidget {
  /// The id of the task being viewed. Passed down to every tab so they can
  /// fetch their slice of data.
  final int taskId;

  /// Optional task title to show in each tab's header while the full payload
  /// is still loading. Helps avoid a flash of "…" on initial open when we
  /// navigate from a card that already knows the title.
  final String? initialTitle;

  /// Which tab to show first. Defaults to [TaskDetailTab.time].
  final TaskDetailTab initialTab;

  const TaskDetailShell({
    super.key,
    required this.taskId,
    this.initialTitle,
    this.initialTab = TaskDetailTab.time,
  });

  @override
  State<TaskDetailShell> createState() => _TaskDetailShellState();
}

class _TaskDetailShellState extends State<TaskDetailShell> {
  late TaskDetailTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
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
        return _PlaceholderTab(
          title: 'Attachments'.tr(context),
          icon: Icons.attach_file_rounded,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.activity:
        return _PlaceholderTab(
          title: 'Activity'.tr(context),
          icon: Icons.timeline_rounded,
          initialTitle: widget.initialTitle,
        );
      case TaskDetailTab.details:
        return _PlaceholderTab(
          title: 'Details'.tr(context),
          icon: Icons.info_outline_rounded,
          initialTitle: widget.initialTitle,
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

// ═══════════════════════════════════════════════════════════════════
// Placeholder for the tabs that are not built yet.
// ═══════════════════════════════════════════════════════════════════

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? initialTitle;

  const _PlaceholderTab({
    required this.title,
    required this.icon,
    required this.initialTitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        // Minimal matching header so the screen still feels anchored while
        // these tabs are under construction.
        Container(
          decoration: const BoxDecoration(gradient: AppColors.navyGradient),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 14,
            left: 14,
            right: 14,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if ((initialTitle ?? '').isNotEmpty)
                      Text(
                        initialTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: colors.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'Coming soon'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
