import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';

import '../../data/models/project_dashboard_model.dart';
import '../providers/project_dashboard_provider.dart';
import '../providers/projects_brief_provider.dart';
import '../widgets/project_dashboard_editable_block.dart';
import 'project_documents_tab_content.dart';

/// Full-screen project KPI dashboard (`GET /api/v1/projects/{id}/dashboard`).
class ProjectDashboardScreen extends ConsumerWidget {
  final int projectId;

  const ProjectDashboardScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectDashboardProvider(projectId));

    return async.when(
      loading: () => Scaffold(
        backgroundColor: context.appColors.bg,
        body: Column(
          children: [
            _TopBar(
              title: 'Project dashboard'.tr(context),
              onBack: () => context.pop(),
            ),
            const Expanded(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.appColors.bg,
        body: Column(
          children: [
            _TopBar(
              title: 'Project dashboard'.tr(context),
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _ErrorBody(
                error: e,
                onRetry: () =>
                    ref.invalidate(projectDashboardProvider(projectId)),
              ),
            ),
          ],
        ),
      ),
      data: (data) => _ProjectDashboardShell(
        data: data,
        projectId: projectId,
        onBack: () => context.pop(),
        onRefresh: () async {
          ref.invalidate(projectDashboardProvider(projectId));
          ref.invalidate(projectDetailsProvider(projectId));
          await ref.read(projectDashboardProvider(projectId).future);
        },
      ),
    );
  }
}

/// Same UX as [TaskDetailShell] bottom bar: emoji + label + active underline.
class _ProjectDashboardShell extends StatefulWidget {
  final ProjectDashboardData data;
  final int projectId;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  const _ProjectDashboardShell({
    required this.data,
    required this.projectId,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  State<_ProjectDashboardShell> createState() => _ProjectDashboardShellState();
}

class _ProjectDashboardShellState extends State<_ProjectDashboardShell> {
  _ProjectTab _tab = _ProjectTab.details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: _tab == _ProjectTab.details
          ? Column(
              children: [
                _ProjectDetailsAppHeader(
                  code: widget.data.project.code,
                  name: widget.data.project.name,
                  onBack: widget.onBack,
                  onRefresh: () async {
                    await widget.onRefresh();
                  },
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primaryMid,
                    onRefresh: widget.onRefresh,
                    child: _DashboardBody(
                      projectId: widget.projectId,
                      data: widget.data,
                      onDataChanged: widget.onRefresh,
                    ),
                  ),
                ),
              ],
            )
          : ProjectDocumentsTabContent(
              projectId: widget.projectId,
              projectName: widget.data.project.name,
              projectCode: widget.data.project.code,
              onBack: widget.onBack,
            ),
      bottomNavigationBar: _ProjectBottomNav(
        current: _tab,
        onChanged: (t) => setState(() => _tab = t),
      ),
    );
  }
}

enum _ProjectTab { details, attachments }

class _ProjectBottomNav extends StatelessWidget {
  final _ProjectTab current;
  final ValueChanged<_ProjectTab> onChanged;

  const _ProjectBottomNav({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(top: BorderSide(color: colors.gray100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              _ProjectNavItem(
                icon: '📋',
                label: 'Details'.tr(context),
                active: current == _ProjectTab.details,
                onTap: () => onChanged(_ProjectTab.details),
              ),
              _ProjectNavItem(
                icon: '📎',
                label: 'Attachments'.tr(context),
                active: current == _ProjectTab.attachments,
                onTap: () => onChanged(_ProjectTab.attachments),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectNavItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ProjectNavItem({
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
                child: Text(icon, style: const TextStyle(fontSize: 22)),
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

/// Task [DetailsTab] app-bar pattern: gradient, back, “Details” + `code · name`, refresh.
class _ProjectDetailsAppHeader extends StatelessWidget {
  final String code;
  final String name;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  const _ProjectDetailsAppHeader({
    required this.code,
    required this.name,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: EdgeInsetsDirectional.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        start: 14,
        end: 14,
      ),
      child: Row(
        children: [
          _NavyHeaderIconButton(
            icon: Icons.arrow_back,
            onTap: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                if (name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      code.trim().isEmpty ? name : '$code · $name',
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
          _NavyHeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: () {
              onRefresh();
            },
          ),
        ],
      ),
    );
  }
}

class _NavyHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavyHeaderIconButton({required this.icon, required this.onTap});

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
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(8, top + 8, 14, 14),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorBody({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ui = GlobalErrorHandler.handle(error);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.error_outline_rounded, size: 48, color: colors.textMuted),
        const SizedBox(height: 12),
        Text(
          'Failed to load dashboard'.tr(context),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ui.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Retry'.tr(context),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final int projectId;
  final ProjectDashboardData data;
  final Future<void> Function() onDataChanged;

  const _DashboardBody({
    required this.projectId,
    required this.data,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = data.project;
    final colors = context.appColors;
    ref.watch(projectDetailsProvider(projectId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (p.isOverdue)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Banner(
              text: 'Project overdue'.tr(context),
              color: AppColors.errorSoft,
              border: AppColors.error,
              icon: Icons.warning_amber_rounded,
            ),
          ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.code,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ProjectDashboardEditableBlock(
                projectId: projectId,
                data: data,
                onDataChanged: onDataChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Task counts'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _CountsGrid(counts: data.counts),
        const SizedBox(height: 18),
        Text(
          'Tasks by status'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.tasksByStatus.map((row) {
            return _StatusPill(
              label: row.status.label,
              count: row.count,
              color: _parseHexColor(row.status.color, const Color(0xFF9CA3AF)),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Team'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${data.team.membersCount}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryMid,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...data.team.members.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemberCard(member: m),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final Color border;
  final IconData icon;

  const _Banner({
    required this.text,
    required this.color,
    required this.border,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: border, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CountsGrid extends StatelessWidget {
  final ProjectDashboardCounts counts;

  const _CountsGrid({required this.counts});

  @override
  Widget build(BuildContext context) {
    final items = <_CountItem>[
      _CountItem(
        'Total tasks'.tr(context),
        counts.tasksTotal,
        Icons.layers_rounded,
      ),
      _CountItem(
        'Root tasks'.tr(context),
        counts.tasksRoot,
        Icons.account_tree_outlined,
      ),
      _CountItem(
        'Subtasks'.tr(context),
        counts.tasksSubtask,
        Icons.subdirectory_arrow_right_rounded,
      ),
      _CountItem(
        'Unassigned'.tr(context),
        counts.tasksUnassigned,
        Icons.person_off_outlined,
      ),
    ];
    // Avoid GridView.shrinkWrap — it can leave a large blank gap above the
    // first row; a simple 2×2 Column/Row has predictable height.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CountTile(
                title: items[0].title,
                value: items[0].value,
                icon: items[0].icon,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountTile(
                title: items[1].title,
                value: items[1].value,
                icon: items[1].icon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CountTile(
                title: items[2].title,
                value: items[2].value,
                icon: items[2].icon,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountTile(
                title: items[3].title,
                value: items[3].value,
                icon: items[3].icon,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountItem {
  final String title;
  final int value;
  final IconData icon;
  _CountItem(this.title, this.value, this.icon);
}

class _CountTile extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _CountTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryMid),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TeamMemberDashboard member;

  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final e = member.employee;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  e.name.trim().isEmpty
                      ? '?'
                      : String.fromCharCodes(e.name.runes.take(1)),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryMid,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      e.code,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (member.isManagerRole)
                _Badge(label: member.roleLabel, color: AppColors.gold)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.gray50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.roleLabel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${'Tasks assigned'.tr(context)}: ${member.tasksAssignedTotal}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          if (member.tasksByStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: member.tasksByStatus.where((r) => r.count > 0).map((
                row,
              ) {
                final c = _parseHexColor(
                  row.status.color,
                  const Color(0xFF9CA3AF),
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${row.status.label} ${row.count}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

Color _parseHexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}
