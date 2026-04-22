import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../../data/models/task_details_model.dart';
import '../../../../data/models/task_models.dart' show TaskStatusRef;
import '../../../../data/models/task_priority_model.dart';
import '../../../../data/models/task_status_model.dart';
import '../../../providers/task_details_provider.dart';
import '../../../providers/task_statuses_provider.dart';
import '../task_detail_shell.dart' show TaskDetailTab;

/// "Details" tab of the task detail screen.
///
/// Renders the full task payload returned by `GET /tasks/{id}` as a
/// single scrollable form-style view. Every editable field is gated by
/// its own permission flag (`permissions.can_edit_*`) — when true, an
/// edit pencil opens a dedicated bottom-sheet editor; when false, the
/// field is plain text.
///
/// Counters (subtasks / comments / attachments / time logs) are tappable
/// cards that jump to the matching sibling tab via [onNavigateToTab].
///
/// Delete (project manager only) sits in the header as a red trash icon.
/// After a successful delete the screen pops back to the previous route
/// (typically the task list).
class DetailsTab extends ConsumerStatefulWidget {
  final int taskId;
  final String? initialTitle;

  /// Shell-level callback: the Details tab taps a counter, the shell
  /// swaps its active tab accordingly. Passed down from
  /// `TaskDetailShell._buildTab`.
  final ValueChanged<TaskDetailTab> onNavigateToTab;

  const DetailsTab({
    super.key,
    required this.taskId,
    required this.onNavigateToTab,
    this.initialTitle,
  });

  @override
  ConsumerState<DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends ConsumerState<DetailsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskDetailsProvider(widget.taskId).notifier).load();
    });
  }

  Future<void> _refresh() async {
    await ref.read(taskDetailsProvider(widget.taskId).notifier).load();
  }

  // ── Field edit dispatchers ────────────────────────────────────────

  Future<void> _patch(Map<String, dynamic> changes) async {
    try {
      await ref
          .read(taskDetailsProvider(widget.taskId).notifier)
          .patch(changes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  Future<void> _editTitle(TaskDetails d) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Title'.tr(context),
        initialValue: d.title,
        maxLength: 500,
        minLines: 1,
        maxLines: 3,
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) return 'Please enter the task title'.tr(context);
          if (s.length < 3) {
            return 'Title must be at least 3 characters'.tr(context);
          }
          if (s.length > 500) {
            return 'Title must not exceed 500 characters'.tr(context);
          }
          return null;
        },
      ),
    );
    if (result == null || result.trim() == d.title.trim()) return;
    await _patch({'title': result.trim()});
  }

  Future<void> _editDescription(TaskDetails d) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Description'.tr(context),
        initialValue: d.description ?? '',
        maxLength: 5000,
        minLines: 5,
        maxLines: 10,
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.length > 5000) {
            return 'Description must not exceed 5000 characters'
                .tr(context);
          }
          return null;
        },
      ),
    );
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed == (d.description ?? '').trim()) return;
    await _patch({'description': trimmed});
  }

  Future<void> _editStatus(TaskDetails d) async {
    final statuses =
        ref.read(taskStatusesProvider).asData?.value ?? const <TaskStatus>[];
    final picked = await showModalBottomSheet<TaskStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusPickerSheet(
        statuses: statuses,
        currentCode: d.status?.code,
      ),
    );
    if (picked == null || picked.code == d.status?.code) return;
    await _patch({'status': picked.code});
  }

  Future<void> _editPriority(TaskDetails d) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriorityPickerSheet(currentCode: d.priority?.code),
    );
    if (picked == null || picked == d.priority?.code) return;
    await _patch({'priority': picked});
  }

  Future<void> _editDueDate(TaskDetails d) async {
    final initial = _parseYmd(d.dueDate) ?? DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DatePickerSheet(initial: initial),
    );
    if (picked == null) return;
    final formatted = _formatYmd(picked);
    if (formatted == d.dueDate) return;
    await _patch({'due_date': formatted});
  }

  Future<void> _editProgress(TaskDetails d) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProgressSliderSheet(current: d.progressPercent),
    );
    if (picked == null || picked == d.progressPercent) return;
    await _patch({'progress_percent': picked});
  }

  Future<void> _editAssignee(TaskDetails d) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssigneePickerSheet(
        members: d.team.projectMembers,
        currentAssigneeId: d.assignee?.id,
      ),
    );
    if (picked == null || picked == d.assignee?.id) return;
    await _patch({'assignee_employee_id': picked});
  }

  Future<void> _editMembers(TaskDetails d) async {
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembersPickerSheet(
        members: d.team.projectMembers,
        initiallySelected: d.team.taskMemberIds.toSet(),
        assigneeId: d.team.assigneeId,
      ),
    );
    if (picked == null) return;
    // Bail if nothing changed
    final before = d.team.taskMemberIds.toSet();
    final after = picked.toSet();
    if (before.length == after.length && before.containsAll(after)) return;
    await _patch({'members': picked});
  }

  // ── Delete ────────────────────────────────────────────────────────

  Future<void> _confirmDelete(TaskDetails d) async {
    // Server behavior: deleting a task is a *soft* delete — it does NOT
    // cascade to its subtasks. Surface that clearly to the PM so they
    // aren't surprised afterward ("wait, where are my child tasks?").
    // The info banner only appears when subtasks actually exist.
    final hasSubtasks = d.counts.subtasks > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          title: Text(
            'Delete task'.tr(ctx),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this task?'.tr(ctx),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              if (hasSubtasks) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryMid.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.primaryMid,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only this task will be deleted. Its subtasks will remain unaffected.'
                              .tr(ctx),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            height: 1.5,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel'.tr(ctx),
                  style: const TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete'.tr(ctx),
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(taskDetailsProvider(widget.taskId).notifier).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task deleted'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Pop back to the task list (or whatever was previously on the
      // nav stack).
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/my-tasks');
      }
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskDetailsProvider(widget.taskId));
    final colors = context.appColors;
    final d = state.details;

    // Wrapping the body in a `Stack` so we can paint a full-screen
    // blocking overlay while a save/delete round-trip is in flight.
    // `AbsorbPointer` inside the overlay blocks taps on the content
    // underneath — users can't edit two things at once or cancel mid-
    // request.
    final busy = state.isSaving || state.isDeleting;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                parentTitle: d?.title ?? widget.initialTitle ?? '',
                code: d?.code,
                canDelete: d?.permissions.canDelete == true,
                isDeleting: state.isDeleting,
                isSaving: state.isSaving,
                onBack: () => Navigator.of(context).maybePop(),
                onRefresh: _refresh,
                onDelete: d == null ? null : () => _confirmDelete(d),
              ),
              Expanded(
                child: Container(
                  color: colors.bg,
                  child: state.isLoading && d == null
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null && d == null
                          ? _ErrorView(
                              message: state.error!,
                              onRetry: _refresh,
                            )
                          : d == null
                              ? const SizedBox.shrink()
                              : _Body(
                                  details: d,
                                  onNavigateToTab: widget.onNavigateToTab,
                                  onEditTitle: () => _editTitle(d),
                                  onEditDescription: () =>
                                      _editDescription(d),
                                  onEditStatus: () => _editStatus(d),
                                  onEditPriority: () => _editPriority(d),
                                  onEditDueDate: () => _editDueDate(d),
                                  onEditProgress: () => _editProgress(d),
                                  onEditAssignee: () => _editAssignee(d),
                                  onEditMembers: () => _editMembers(d),
                                  onRefresh: _refresh,
                                ),
                ),
              ),
            ],
          ),
          // Full-screen busy overlay — covers header + body (and the
          // back button, so the user can't navigate mid-save). The
          // Scaffold's bottom nav (owned by the parent shell) remains
          // visible below, which is fine: tapping it just switches tab
          // state — the save continues in the background and the
          // resulting snack bar still fires.
          if (busy)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        state.isDeleting
                            ? 'Deleting...'.tr(context)
                            : 'Saving...'.tr(context),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header — navy gradient + back + refresh + delete
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String parentTitle;
  final String? code;
  final bool canDelete;
  final bool isDeleting;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onDelete;

  const _Header({
    required this.parentTitle,
    required this.canDelete,
    required this.isDeleting,
    required this.isSaving,
    required this.onBack,
    required this.onRefresh,
    required this.onDelete,
    this.code,
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
      child: Row(
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
                      'Details'.tr(context),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (isSaving) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                if (parentTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      code == null || code!.isEmpty
                          ? parentTitle
                          : '$code · $parentTitle',
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
          if (canDelete) ...[
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.delete_outline_rounded,
              onTap: isDeleting ? () {} : (onDelete ?? () {}),
              tint: AppColors.error,
              loading: isDeleting,
            ),
          ],
          const SizedBox(width: 6),
          _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;
  final bool loading;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tint,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tint != null
              ? tint!.withValues(alpha: 0.20)
              : Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                icon,
                color: tint != null ? Colors.white : Colors.white,
                size: 18,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Body — the big scrollable form
// ═══════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  final TaskDetails details;
  final ValueChanged<TaskDetailTab> onNavigateToTab;
  final VoidCallback onEditTitle;
  final VoidCallback onEditDescription;
  final VoidCallback onEditStatus;
  final VoidCallback onEditPriority;
  final VoidCallback onEditDueDate;
  final VoidCallback onEditProgress;
  final VoidCallback onEditAssignee;
  final VoidCallback onEditMembers;
  final Future<void> Function() onRefresh;

  const _Body({
    required this.details,
    required this.onNavigateToTab,
    required this.onEditTitle,
    required this.onEditDescription,
    required this.onEditStatus,
    required this.onEditPriority,
    required this.onEditDueDate,
    required this.onEditProgress,
    required this.onEditAssignee,
    required this.onEditMembers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final d = details;
    final p = d.permissions;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Breadcrumb
            if (d.path.nodes.isNotEmpty) _BreadcrumbCard(path: d.path),
            const SizedBox(height: 12),

            // Title
            _FieldCard(
              label: 'Title'.tr(context),
              editable: p.canEditTitle,
              onEdit: onEditTitle,
              child: Text(
                d.title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Description
            _FieldCard(
              label: 'Description'.tr(context),
              editable: p.canEditDescription,
              onEdit: onEditDescription,
              child: Text(
                (d.description ?? '').trim().isEmpty
                    ? '—'
                    : d.description!.trim(),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: (d.description ?? '').trim().isEmpty
                      ? context.appColors.textMuted
                      : context.appColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Status + Priority row
            Row(
              children: [
                Expanded(
                  child: _FieldCard(
                    label: 'Status'.tr(context),
                    editable: p.canEditStatus,
                    onEdit: onEditStatus,
                    child: _StatusChip(status: d.status),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FieldCard(
                    label: 'Priority'.tr(context),
                    editable: p.canEditPriority,
                    onEdit: onEditPriority,
                    child: _PriorityChip(priority: d.priority),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress
            _FieldCard(
              label: 'Progress'.tr(context),
              editable: p.canUpdateProgress,
              onEdit: onEditProgress,
              child: _ProgressBar(percent: d.progressPercent),
            ),
            const SizedBox(height: 10),

            // Due date
            _FieldCard(
              label: 'Due date'.tr(context),
              editable: p.canEditDueDate,
              onEdit: onEditDueDate,
              child: _DateValue(
                value: d.dueDate,
                isOverdue: d.isOverdue,
              ),
            ),
            const SizedBox(height: 10),

            // Counts grid — tappable, navigate to sibling tabs
            _CountsGrid(
              counts: d.counts,
              totalHours: d.totalTimeHours,
              onTapSubtasks: () =>
                  onNavigateToTab(TaskDetailTab.subtasks),
              onTapComments: () =>
                  onNavigateToTab(TaskDetailTab.comments),
              onTapAttachments: () =>
                  onNavigateToTab(TaskDetailTab.attachments),
              onTapTimeLogs: () => onNavigateToTab(TaskDetailTab.time),
            ),
            const SizedBox(height: 10),

            // Time breakdown per status
            if (d.statusTimeBreakdown.isNotEmpty) ...[
              _TimeBreakdownCard(breakdown: d.statusTimeBreakdown),
              const SizedBox(height: 10),
            ],

            // Project (read-only)
            if (d.project != null) ...[
              _ProjectCard(project: d.project!),
              const SizedBox(height: 10),
            ],

            // Assignee (PM-only editable)
            _FieldCard(
              label: 'Assignee'.tr(context),
              editable: p.canChangeAssignee,
              onEdit: onEditAssignee,
              child: _AssigneeLine(assignee: d.assignee),
            ),
            const SizedBox(height: 10),

            // Team members (checklist, PM+assignee editable)
            _FieldCard(
              label: 'Team members'.tr(context),
              editable: p.canEditMembers,
              onEdit: onEditMembers,
              child: _MembersList(
                members: d.team.projectMembers,
                assigneeId: d.team.assigneeId,
              ),
            ),
            const SizedBox(height: 10),

            // Audit — created / updated
            _AuditCard(details: d),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Reusable field card — label + optional edit pencil + child
// ═══════════════════════════════════════════════════════════════════

class _FieldCard extends StatelessWidget {
  final String label;
  final bool editable;
  final VoidCallback onEdit;
  final Widget child;

  const _FieldCard({
    required this.label,
    required this.editable,
    required this.onEdit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray100),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (editable)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: AppColors.primaryMid,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Breadcrumb
// ═══════════════════════════════════════════════════════════════════

class _BreadcrumbCard extends StatelessWidget {
  final TaskPath path;
  const _BreadcrumbCard({required this.path});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_rounded,
            size: 14,
            color: colors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              path.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Status / Priority chips
// ═══════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final TaskStatusRef? status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return Text('—', style: _muted(context));
    final color = _parseHex(status!.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status!.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final TaskPriority? priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    if (priority == null) return Text('—', style: _muted(context));
    final color = _parseHex(priority!.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              priority!.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int percent;
  const _ProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final clamped = percent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppFuns.replaceArabicNumbers('$clamped')}%',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 6,
            backgroundColor: colors.gray100,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryMid),
          ),
        ),
      ],
    );
  }
}

class _DateValue extends StatelessWidget {
  final String? value;
  final bool isOverdue;
  const _DateValue({required this.value, this.isOverdue = false});

  @override
  Widget build(BuildContext context) {
    if ((value ?? '').isEmpty) return Text('—', style: _muted(context));
    final colors = context.appColors;
    return Row(
      children: [
        Icon(
          Icons.event_rounded,
          size: 14,
          color: isOverdue ? AppColors.error : colors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          AppFuns.replaceArabicNumbers(value!),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isOverdue ? AppColors.error : colors.textPrimary,
          ),
        ),
        if (isOverdue) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Overdue'.tr(context),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Counts grid
// ═══════════════════════════════════════════════════════════════════

class _CountsGrid extends StatelessWidget {
  final TaskCounts counts;
  final double totalHours;
  final VoidCallback onTapSubtasks;
  final VoidCallback onTapComments;
  final VoidCallback onTapAttachments;
  final VoidCallback onTapTimeLogs;

  const _CountsGrid({
    required this.counts,
    required this.totalHours,
    required this.onTapSubtasks,
    required this.onTapComments,
    required this.onTapAttachments,
    required this.onTapTimeLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CountTile(
                icon: Icons.account_tree_rounded,
                color: const Color(0xFF7C3AED),
                label: 'Subtasks'.tr(context),
                value: '${counts.subtasks}',
                onTap: onTapSubtasks,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountTile(
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Comments'.tr(context),
                value: '${counts.comments}',
                onTap: onTapComments,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CountTile(
                icon: Icons.attach_file_rounded,
                color: const Color(0xFF10B981),
                label: 'Attachments'.tr(context),
                value: '${counts.attachments}',
                onTap: onTapAttachments,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountTile(
                icon: Icons.timer_outlined,
                color: const Color(0xFFF59E0B),
                label: 'Time'.tr(context),
                value: '${counts.timeLogs}',
                // Sub-line: total hours ("12.5h") under the count.
                subline: totalHours > 0
                    ? '${AppFuns.replaceArabicNumbers(totalHours.toStringAsFixed(1))}h'
                    : null,
                onTap: onTapTimeLogs,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subline;
  final VoidCallback onTap;

  const _CountTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.subline,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.gray100),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          AppFuns.replaceArabicNumbers(value),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (subline != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            subline!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 12,
                color: colors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Time breakdown per status
// ═══════════════════════════════════════════════════════════════════

class _TimeBreakdownCard extends StatelessWidget {
  final List<StatusTimeBreakdown> breakdown;
  const _TimeBreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time in each status'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in breakdown) _TimeBreakdownPill(entry: b),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBreakdownPill extends StatelessWidget {
  final StatusTimeBreakdown entry;
  const _TimeBreakdownPill({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(entry.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            entry.label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            AppFuns.replaceArabicNumbers(entry.durationLabel),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Project + Assignee + Members
// ═══════════════════════════════════════════════════════════════════

class _ProjectCard extends StatelessWidget {
  final TaskProjectInfo project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryMid.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.folder_rounded,
                  color: AppColors.primaryMid,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (project.code != null && project.code!.isNotEmpty)
                      Text(
                        project.code!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (project.manager != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_rounded,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${'Project manager'.tr(context)}:  ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
                Expanded(
                  child: Text(
                    project.manager!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
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

class _AssigneeLine extends StatelessWidget {
  final SimpleEmployeeRef? assignee;
  const _AssigneeLine({required this.assignee});

  @override
  Widget build(BuildContext context) {
    if (assignee == null) return Text('—', style: _muted(context));
    final colors = context.appColors;
    final initial =
        assignee!.name.isEmpty ? '?' : assignee!.name.characters.first;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryMid.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryMid,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            assignee!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Read-only preview of the team list — used inside the field card.
/// Actual editing is done via the `_MembersPickerSheet` modal.
class _MembersList extends StatelessWidget {
  final List<TaskTeamMember> members;
  final int? assigneeId;
  const _MembersList({required this.members, required this.assigneeId});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final taskMembers = members.where((m) => m.isTaskMember).toList();
    if (taskMembers.isEmpty) {
      return Text('No team members'.tr(context), style: _muted(context));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in taskMembers)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.gray100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.isTaskAssignee) ...[
                  const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppColors.primaryMid,
                  ),
                  const SizedBox(width: 4),
                ] else if (m.isProjectManager) ...[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 12,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  m.name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Audit — created / updated
// ═══════════════════════════════════════════════════════════════════

class _AuditCard extends StatelessWidget {
  final TaskDetails details;
  const _AuditCard({required this.details});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.createdAt != null || details.createdBy != null) ...[
            _AuditLine(
              icon: Icons.add_circle_outline_rounded,
              label: 'Created'.tr(context),
              actor: details.createdBy?.name,
              when: details.createdAt,
            ),
            const SizedBox(height: 8),
          ],
          if (details.updatedAt != null || details.updatedBy != null)
            _AuditLine(
              icon: Icons.edit_note_rounded,
              label: 'Last updated'.tr(context),
              actor: details.updatedBy?.name,
              when: details.updatedAt,
            ),
        ],
      ),
    );
  }
}

class _AuditLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? actor;
  final DateTime? when;
  const _AuditLine({
    required this.icon,
    required this.label,
    required this.actor,
    required this.when,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final parts = <String>[];
    if ((actor ?? '').isNotEmpty) parts.add(actor!);
    if (when != null) parts.add(AppFuns.formatDateTime(when!.toLocal()));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                parts.isEmpty ? '—' : parts.join(' · '),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Edit bottom sheets
// ═══════════════════════════════════════════════════════════════════

/// Generic multiline text editor — used for title + description.
class _TextEditSheet extends StatefulWidget {
  final String title;
  final String initialValue;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;

  const _TextEditSheet({
    required this.title,
    required this.initialValue,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    this.validator,
  });

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.gray200,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _controller,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.bgCard,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.gray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.gray200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryMid, width: 1.4),
                    ),
                  ),
                  validator: widget.validator,
                ),
                const SizedBox(height: 12),
                _SheetActions(onCancel: () => Navigator.pop(context), onSave: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPickerSheet extends StatelessWidget {
  final List<TaskStatus> statuses;
  final String? currentCode;

  const _StatusPickerSheet({
    required this.statuses,
    required this.currentCode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Choose status'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final s in statuses)
              InkWell(
                onTap: () => Navigator.of(context).pop(s),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _parseHex(s.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (s.code == currentCode)
                        const Icon(Icons.check_rounded,
                            color: AppColors.primaryMid),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriorityPickerSheet extends StatelessWidget {
  final String? currentCode;
  const _PriorityPickerSheet({required this.currentCode});

  static const _options = [
    ('LOW', 'Low', Color(0xFF10B981)),
    ('MEDIUM', 'Medium', Color(0xFF3B82F6)),
    ('HIGH', 'High', Color(0xFFF59E0B)),
    ('CRITICAL', 'Critical', Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Choose priority'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final (code, label, color) in _options)
              InkWell(
                onTap: () => Navigator.of(context).pop(code),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (code == currentCode)
                        const Icon(Icons.check_rounded,
                            color: AppColors.primaryMid),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerSheet extends StatefulWidget {
  final DateTime initial;
  const _DatePickerSheet({required this.initial});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected;
  late DateTime _focused;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _focused = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Due date'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.gray200),
              ),
              clipBehavior: Clip.antiAlias,
              child: TableCalendar<void>(
                firstDay:
                    DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
                focusedDay: _focused,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: ''},
                availableGestures: AvailableGestures.horizontalSwipe,
                startingDayOfWeek: StartingDayOfWeek.saturday,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (sel, f) {
                  setState(() {
                    _selected = DateTime(sel.year, sel.month, sel.day);
                    _focused = f;
                  });
                },
                onPageChanged: (f) => _focused = f,
                calendarBuilders: CalendarBuilders(
                  headerTitleBuilder: (_, day) => Center(
                    child: Text(
                      AppFuns.formatMonthYear(day),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left_rounded,
                      color: colors.textSecondary),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded,
                      color: colors.textSecondary),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primaryMid,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color:
                        AppColors.primaryMid.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryMid,
                  ),
                  defaultTextStyle: TextStyle(
                      fontFamily: 'Cairo', color: colors.textPrimary),
                  weekendTextStyle: TextStyle(
                      fontFamily: 'Cairo', color: colors.textSecondary),
                  outsideTextStyle: TextStyle(
                      fontFamily: 'Cairo', color: colors.textDisabled),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SheetActions(
              onCancel: () => Navigator.pop(context),
              onSave: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSliderSheet extends StatefulWidget {
  final int current;
  const _ProgressSliderSheet({required this.current});

  @override
  State<_ProgressSliderSheet> createState() => _ProgressSliderSheetState();
}

class _ProgressSliderSheetState extends State<_ProgressSliderSheet> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.current.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              '${'Progress'.tr(context)} — ${AppFuns.replaceArabicNumbers('$_value')}%',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Slider(
              value: _value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: AppColors.primaryMid,
              onChanged: (v) => setState(() => _value = v.round()),
            ),
            const SizedBox(height: 6),
            _SheetActions(
              onCancel: () => Navigator.pop(context),
              onSave: () => Navigator.of(context).pop(_value),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneePickerSheet extends StatelessWidget {
  final List<TaskTeamMember> members;
  final int? currentAssigneeId;
  const _AssigneePickerSheet({
    required this.members,
    required this.currentAssigneeId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Choose assignee'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colors.gray100,
                  indent: 12,
                  endIndent: 12,
                ),
                itemBuilder: (_, i) {
                  final m = members[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(m.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (m.isProjectManager)
                            _MiniBadge(
                              label: 'Project manager'.tr(context),
                              color: const Color(0xFF7C3AED),
                            ),
                          if (m.id == currentAssigneeId) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_rounded,
                                color: AppColors.primaryMid),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersPickerSheet extends StatefulWidget {
  final List<TaskTeamMember> members;
  final Set<int> initiallySelected;
  final int? assigneeId;

  const _MembersPickerSheet({
    required this.members,
    required this.initiallySelected,
    required this.assigneeId,
  });

  @override
  State<_MembersPickerSheet> createState() => _MembersPickerSheetState();
}

class _MembersPickerSheetState extends State<_MembersPickerSheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Team members'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.members.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colors.gray100,
                  indent: 12,
                  endIndent: 12,
                ),
                itemBuilder: (_, i) {
                  final m = widget.members[i];
                  final isAssignee = m.id == widget.assigneeId;
                  final isSelected = _selected.contains(m.id);
                  return CheckboxListTile(
                    value: isSelected,
                    // Assignee can't be un-checked — the server silently
                    // re-adds them anyway; we enforce the same locally
                    // so the UX is predictable.
                    onChanged: isAssignee
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected.add(m.id);
                              } else {
                                _selected.remove(m.id);
                              }
                            }),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primaryMid,
                    dense: true,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (m.isProjectManager)
                          _MiniBadge(
                            label: 'Project manager'.tr(context),
                            color: const Color(0xFF7C3AED),
                          ),
                        if (isAssignee) ...[
                          const SizedBox(width: 4),
                          _MiniBadge(
                            label: 'Assignee'.tr(context),
                            color: AppColors.primaryMid,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _SheetActions(
              onCancel: () => Navigator.pop(context),
              onSave: () => Navigator.of(context).pop(_selected.toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  const _SheetActions({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: colors.gray300, width: 1.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onCancel,
            child: Text(
              'Cancel'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onSave,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              'Save'.tr(context),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Error view
// ═══════════════════════════════════════════════════════════════════

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

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}

TextStyle _muted(BuildContext context) => TextStyle(
      fontFamily: 'Cairo',
      fontSize: 13,
      color: context.appColors.textMuted,
    );

DateTime? _parseYmd(String? ymd) {
  if (ymd == null || ymd.trim().isEmpty) return null;
  return DateTime.tryParse(ymd);
}

String _formatYmd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
