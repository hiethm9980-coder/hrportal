import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';

import '../../data/models/project_dashboard_model.dart';
import '../../data/models/project_details_model.dart';
import '../../data/models/project_member_models.dart';
import '../providers/projects_brief_provider.dart'
    show projectDetailsProvider, projectsBriefProvider;

bool _isRtl(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl;

/// Places narrow value chips/rows on the end side of the card in both modes.
AlignmentDirectional _valueAlign(BuildContext context) => _isRtl(context)
    ? AlignmentDirectional.centerStart
    : AlignmentDirectional.centerEnd;

/// Add-only vs remove-only for the project team bottom sheet.
enum _ManageTeamMode { add, remove }

/// Card-style block mirroring the task [DetailsTab] field cards, gated to
/// project manager via [ProjectPermissions.canCreateTask] (same as Add Task FAB).
class ProjectDashboardEditableBlock extends ConsumerStatefulWidget {
  final int projectId;
  final ProjectDashboardData data;
  final Future<void> Function() onDataChanged;

  const ProjectDashboardEditableBlock({
    super.key,
    required this.projectId,
    required this.data,
    required this.onDataChanged,
  });

  @override
  ConsumerState<ProjectDashboardEditableBlock> createState() =>
      _ProjectDashboardEditableBlockState();
}

class _ProjectDashboardEditableBlockState
    extends ConsumerState<ProjectDashboardEditableBlock> {
  bool _busy = false;

  String get _apiKeyName => 'name';
  String get _apiKeyDescription => 'description';
  String get _apiKeyStatus => 'status';
  String get _apiKeyPriority => 'priority';
  String get _apiKeyProgress => 'progress_percent';
  String get _apiKeyStart => 'start_date';
  String get _apiKeyEnd => 'end_date';

  bool _canEdit(ProjectDetails? d) => d?.permissions.canCreateTask == true;

  Future<void> _patch(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    final d = ref.read(projectDetailsProvider(widget.projectId)).value;
    if (!_canEdit(d)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(projectRepositoryProvider);
      await repo.updateProject(widget.projectId, changes);
      if (!mounted) return;
      ref.invalidate(projectDetailsProvider(widget.projectId));
      await widget.onDataChanged();
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
      if (mounted) {
        GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(projectDetailsProvider(widget.projectId));
    final p = widget.data.project;
    final canEdit = _canEdit(details.value);
    ref.watch(projectsBriefProvider);
    final colors = context.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (_busy) const SizedBox(height: 4),
            _FieldCard(
              label: 'Title'.tr(context),
              editable: canEdit,
              onEdit: canEdit
                  ? () => _onEditName(context, p, _apiKeyName)
                  : () {},
              child: Text(
                p.name,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 10),
            _FieldCard(
              label: 'Description'.tr(context),
              editable: canEdit,
              onEdit: canEdit
                  ? () => _onEditDescription(context, p, _apiKeyDescription)
                  : () {},
              child: Text(
                (p.description ?? '').trim().isEmpty
                    ? '—'
                    : p.description!.trim(),
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.5,
                  color: (p.description ?? '').trim().isEmpty
                      ? colors.textMuted
                      : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FieldCard(
                    label: 'Status'.tr(context),
                    editable: canEdit,
                    onEdit: canEdit
                        ? () => _onEditStatus(context, p, _apiKeyStatus)
                        : () {},
                    child: _StatusChipLcc(status: p.status),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FieldCard(
                    label: 'Priority'.tr(context),
                    editable: canEdit,
                    onEdit: canEdit
                        ? () => _onEditPriority(context, p, _apiKeyPriority)
                        : () {},
                    child: p.priority != null
                        ? _StatusChipLcc(
                            status: p.priority!,
                            leadingIcon: Icons.flag_rounded,
                          )
                        : Text('—', style: _muted(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _FieldCard(
              label: 'Progress'.tr(context),
              editable: canEdit,
              onEdit: canEdit
                  ? () => _onEditProgress(context, p, _apiKeyProgress)
                  : () {},
              child: _ProgressValue(percent: p.progressPercent),
            ),
            const SizedBox(height: 10),
            _FieldCard(
              label: 'Start date'.tr(context),
              editable: canEdit,
              onEdit: canEdit
                  ? () => _onEditDate(context, p, _apiKeyStart, p.startDate)
                  : () {},
              child: _YmdValue(value: p.startDate, isLate: false),
            ),
            const SizedBox(height: 10),
            _FieldCard(
              label: 'End date'.tr(context),
              editable: canEdit,
              onEdit: canEdit
                  ? () => _onEditDate(context, p, _apiKeyEnd, p.endDate)
                  : () {},
              child: _YmdValue(value: p.endDate, isLate: p.isOverdue),
            ),
            const SizedBox(height: 10),
            if (canEdit)
              _ProjectTeamCard(
                memberCount: widget.data.team.membersCount,
                onAdd: () => _onManageTeam(context, _ManageTeamMode.add),
                onRemove: () => _onManageTeam(context, _ManageTeamMode.remove),
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: 10),
            _InfoMetaRow(
              icon: Icons.manage_accounts_outlined,
              text:
                  '${'Project manager'.tr(context)}: ${p.manager.name} (${p.manager.code})',
            ),
          ],
        ),
        if (_busy)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(color: colors.bg.withValues(alpha: 0.2)),
            ),
          ),
      ],
    );
  }

  Future<void> _onEditName(
    BuildContext context,
    ProjectDashboardProject p,
    String key,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Title'.tr(context),
        initialValue: p.name,
        maxLength: 200,
        minLines: 1,
        maxLines: 2,
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) {
            return 'Please enter the task title'.tr(context);
          }
          if (s.length < 3) {
            return 'Title must be at least 3 characters'.tr(context);
          }
          return null;
        },
      ),
    );
    if (result == null) return;
    if (result.trim() == p.name) return;
    await _patch({key: result.trim()});
  }

  Future<void> _onEditDescription(
    BuildContext context,
    ProjectDashboardProject p,
    String key,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: 'Description'.tr(context),
        initialValue: p.description ?? '',
        maxLength: 5000,
        minLines: 4,
        maxLines: 8,
        validator: (v) {
          if ((v ?? '').trim().length > 5000) {
            return 'Description must not exceed 5000 characters'.tr(context);
          }
          return null;
        },
      ),
    );
    if (result == null) return;
    if (result.trim() == (p.description ?? '').trim()) return;
    final t = result.trim();
    await _patch({key: t});
  }

  List<LabelledCodeColor> _statusOptions() {
    final p = widget.data.project;
    final m = <String, LabelledCodeColor>{p.status.code: p.status};
    final list = ref.read(projectsBriefProvider).value;
    if (list != null) {
      for (final x in list) {
        if (x.status != null && x.status!.isNotEmpty) {
          m[x.status!] = LabelledCodeColor(
            code: x.status!,
            label: (x.statusLabel != null && x.statusLabel!.isNotEmpty)
                ? x.statusLabel!
                : x.status!,
            color: x.statusColor,
          );
        }
      }
    }
    return m.values.toList();
  }

  Future<void> _onEditStatus(
    BuildContext context,
    ProjectDashboardProject p,
    String key,
  ) async {
    final options = _statusOptions();
    final picked = await showModalBottomSheet<LabelledCodeColor>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LccPickerSheet(
        title: 'Choose status'.tr(context),
        options: options,
        currentCode: p.status.code,
      ),
    );
    if (picked == null || picked.code == p.status.code) return;
    await _patch({key: picked.code});
  }

  Future<void> _onEditPriority(
    BuildContext context,
    ProjectDashboardProject p,
    String key,
  ) async {
    final current = p.priority?.code;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProjectPrioritySheet(),
    );
    if (picked == null) return;
    if (picked == (current ?? '')) return;
    await _patch({key: picked});
  }

  Future<void> _onEditProgress(
    BuildContext context,
    ProjectDashboardProject p,
    String key,
  ) async {
    final n = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProgressSliderSheet(current: p.progressPercent),
    );
    if (n == null || n == p.progressPercent) return;
    await _patch({key: n.clamp(0, 100)});
  }

  Future<void> _onEditDate(
    BuildContext context,
    ProjectDashboardProject p,
    String key,
    String? ymd,
  ) async {
    final initial = _parseYmd(ymd) ?? DateTime.now();
    final d = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _YmdSheet(initial: initial),
    );
    if (d == null) return;
    final out = _formatYmd(d);
    if (out == (ymd ?? '').trim()) return;
    await _patch({key: out});
  }

  Future<void> _onManageTeam(BuildContext context, _ManageTeamMode mode) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageTeamSheet(
        projectId: widget.projectId,
        team: widget.data.team,
        mode: mode,
        onDone: () async {
          if (!context.mounted) return;
          await widget.onDataChanged();
          ref.invalidate(projectDetailsProvider(widget.projectId));
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Project team: label + count + add/remove actions (not a single pencil)
// ═══════════════════════════════════════════════════════════════════

class _ProjectTeamCard extends StatelessWidget {
  final int memberCount;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProjectTeamCard({
    required this.memberCount,
    required this.onAdd,
    required this.onRemove,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Project team'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${'Team'.tr(context)}: $memberCount',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _TeamActionRow(
            label: 'Add project members'.tr(context),
            icon: Icons.person_add_outlined,
            color: AppColors.primaryMid,
            onTap: onAdd,
          ),
          const SizedBox(height: 6),
          _TeamActionRow(
            label: 'Remove project members'.tr(context),
            icon: Icons.person_remove_outlined,
            color: AppColors.error,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _TeamActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TeamActionRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = _isRtl(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: rtl
                ? [
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, size: 22, color: color),
                  ]
                : [
                    Icon(icon, size: 22, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
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
// Field card (Details tab)
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.start,
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
                  child: const Padding(
                    padding: EdgeInsets.all(4),
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
          Align(alignment: _valueAlign(context), child: child),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Value widgets
// ═══════════════════════════════════════════════════════════════════

class _StatusChipLcc extends StatelessWidget {
  final LabelledCodeColor status;
  final IconData? leadingIcon;

  const _StatusChipLcc({required this.status, this.leadingIcon});

  @override
  Widget build(BuildContext context) {
    final c = _parseHexColor(status.color, AppColors.primaryMid);
    final rtl = _isRtl(context);

    final dotOrIcon = leadingIcon != null
        ? [
            Icon(leadingIcon, size: 12, color: c),
            const SizedBox(width: 4),
          ]
        : [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ];
    final labelW = Flexible(
      child: Text(
        status.label,
        textAlign: TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      constraints: const BoxConstraints(minWidth: 0),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      // Order depends on [Directionality]: in RTL, first child is on the
      // visual "start" of the line (the right) — label, then leading dot/icon.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (rtl) ...[labelW, ...dotOrIcon] else ...[...dotOrIcon, labelW],
        ],
      ),
    );
  }
}

class _ProgressValue extends StatelessWidget {
  final int percent;
  const _ProgressValue({required this.percent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final v = percent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${AppFuns.replaceArabicNumbers('$v')}%',
          textAlign: TextAlign.start,
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
            value: v / 100,
            minHeight: 6,
            backgroundColor: colors.gray100,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryMid),
          ),
        ),
      ],
    );
  }
}

class _YmdValue extends StatelessWidget {
  final String? value;
  final bool isLate;

  const _YmdValue({required this.value, required this.isLate});

  @override
  Widget build(BuildContext context) {
    if ((value ?? '').isEmpty) {
      return Text('—', style: _muted(context), textAlign: TextAlign.start);
    }
    final colors = context.appColors;
    final rtl = _isRtl(context);

    final cal = Icon(
      Icons.event_rounded,
      size: 14,
      color: isLate ? AppColors.error : colors.textSecondary,
    );
    final valueText = Flexible(
      child: Text(
        AppFuns.replaceArabicNumbers(value!),
        textAlign: TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isLate ? AppColors.error : colors.textPrimary,
        ),
      ),
    );
    Widget overdueBadge() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rtl
          ? [
              valueText,
              const SizedBox(width: 6),
              cal,
              if (isLate) const SizedBox(width: 6),
              if (isLate) overdueBadge(),
            ]
          : [
              cal,
              const SizedBox(width: 6),
              valueText,
              if (isLate) const SizedBox(width: 6),
              if (isLate) overdueBadge(),
            ],
    );
  }
}

class _InfoMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoMetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rtl = _isRtl(context);
    final body = Text(
      text,
      textAlign: TextAlign.start,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        height: 1.4,
        color: colors.textSecondary,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rtl
          ? [
              Expanded(child: body),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: colors.textMuted),
            ]
          : [
              Icon(icon, size: 16, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(child: body),
            ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Pickers
// ═══════════════════════════════════════════════════════════════════

class _LccPickerSheet extends StatelessWidget {
  final String title;
  final List<LabelledCodeColor> options;
  final String currentCode;

  const _LccPickerSheet({
    required this.title,
    required this.options,
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
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final s in options)
              InkWell(
                onTap: () => Navigator.of(context).pop(s),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _parseHexColor(s.color, AppColors.primaryMid),
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
                        const Icon(
                          Icons.check_rounded,
                          color: AppColors.primaryMid,
                        ),
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

class _ProjectPrioritySheet extends StatelessWidget {
  const _ProjectPrioritySheet();

  static const _opt = <(String, String, Color)>[
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
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final (code, en, c) in _opt)
              InkWell(
                onTap: () => Navigator.of(context).pop(code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, size: 18, color: c),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          en.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

class _ProgressSliderSheet extends StatefulWidget {
  final int current;
  const _ProgressSliderSheet({required this.current});

  @override
  State<_ProgressSliderSheet> createState() => _ProgressSliderSheetState();
}

class _ProgressSliderSheetState extends State<_ProgressSliderSheet> {
  late int _v;

  @override
  void initState() {
    super.initState();
    _v = widget.current.clamp(0, 100);
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
              '${'Progress'.tr(context)} — ${AppFuns.replaceArabicNumbers('$_v')}%',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Slider(
              value: _v.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: AppColors.primaryMid,
              onChanged: (x) => setState(() => _v = x.round()),
            ),
            const SizedBox(height: 4),
            _SheetActions(
              onCancel: () => Navigator.pop(context),
              onSave: () => Navigator.of(context).pop(_v),
            ),
          ],
        ),
      ),
    );
  }
}

class _YmdSheet extends StatefulWidget {
  final DateTime initial;
  const _YmdSheet({required this.initial});

  @override
  State<_YmdSheet> createState() => _YmdSheetState();
}

class _YmdSheetState extends State<_YmdSheet> {
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.gray200),
                ),
                clipBehavior: Clip.antiAlias,
                child: TableCalendar<void>(
                  firstDay: DateTime.now().subtract(
                    const Duration(days: 365 * 2),
                  ),
                  lastDay: DateTime.now().add(const Duration(days: 365 * 5)),
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
                    headerTitleBuilder: (_, d) {
                      return Center(
                        child: Text(
                          AppFuns.formatMonthYear(d),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    leftChevronIcon: Icon(
                      Icons.chevron_left_rounded,
                      color: colors.textSecondary,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primaryMid,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.primaryMid.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    defaultTextStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: colors.textPrimary,
                    ),
                    weekendTextStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: colors.textSecondary,
                    ),
                    outsideTextStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: colors.textDisabled,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SheetActions(
                onCancel: () => Navigator.pop(context),
                onSave: () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  final _form = GlobalKey<FormState>();
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_c.text);
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _c,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.bgCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                        color: AppColors.primaryMid,
                        width: 1.4,
                      ),
                    ),
                  ),
                  validator: widget.validator,
                ),
                const SizedBox(height: 12),
                _SheetActions(
                  onCancel: () => Navigator.pop(context),
                  onSave: _save,
                ),
              ],
            ),
          ),
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
                borderRadius: BorderRadius.circular(12),
              ),
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
                borderRadius: BorderRadius.circular(12),
              ),
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
// Manage team sheet
// ═══════════════════════════════════════════════════════════════════

class _ManageTeamSheet extends ConsumerStatefulWidget {
  final int projectId;
  final ProjectDashboardTeam team;
  final _ManageTeamMode mode;
  final Future<void> Function() onDone;

  const _ManageTeamSheet({
    required this.projectId,
    required this.team,
    required this.mode,
    required this.onDone,
  });

  @override
  ConsumerState<_ManageTeamSheet> createState() => _ManageTeamSheetState();
}

class _ManageTeamSheetState extends ConsumerState<_ManageTeamSheet> {
  String _q = '';
  final _selected = <int>{};
  bool _loading = false;
  String? _loadError;
  List<ProjectMemberCandidate> _candidates = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == _ManageTeamMode.add) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = ref.read(projectRepositoryProvider);
      final d = await r.getProjectMemberCandidates(
        widget.projectId,
        q: _q.isEmpty ? null : _q,
      );
      if (!mounted) return;
      setState(() {
        _candidates = d.candidates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _add() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = ref.read(projectRepositoryProvider);
      await r.addProjectMembers(widget.projectId, _selected.toList());
      if (!mounted) return;
      setState(() => _selected.clear());
      await widget.onDone();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int employeeId) async {
    setState(() => _loading = true);
    try {
      final r = ref.read(projectRepositoryProvider);
      await r.removeProjectMember(widget.projectId, employeeId);
      if (!mounted) return;
      await widget.onDone();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Valid employee id; not already a project member. (Do not filter
    // `is_project_manager` here — a backend bug could flag everyone and hide
    // the list; the PM is usually already `is_in_project: true`.)
    final toAdd = _candidates.where((c) => c.id > 0 && !c.isInProject).toList();
    final removable = widget.team.members
        .where((m) => !m.isManagerRole)
        .toList();
    final showAdd = widget.mode == _ManageTeamMode.add;
    final showRemove = widget.mode == _ManageTeamMode.remove;
    final sheetTitle = showAdd
        ? 'Add project members'.tr(context)
        : 'Remove project members'.tr(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
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
                sheetTitle,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
              if (showAdd) const SizedBox(height: 8),
              if (showAdd)
                TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.bgCard,
                    hintText: 'Search'.tr(context),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: _load,
                      tooltip: 'Search'.tr(context),
                      icon: const Icon(Icons.search_rounded, size: 22),
                    ),
                  ),
                  onChanged: (v) {
                    _q = v;
                  },
                  onSubmitted: (_) => _load(),
                ),
              if (showAdd && _loadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (showAdd) const SizedBox(height: 12),
              if (showAdd && _loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (showAdd && !_loading) ...[
                if (toAdd.isNotEmpty) ...[
                  Text(
                    'Add team members'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.textSecondary,
                    ),
                  ),
                  for (final c in toAdd)
                    CheckboxListTile(
                      value: _selected.contains(c.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(c.id);
                          } else {
                            _selected.remove(c.id);
                          }
                        });
                      },
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        c.code,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _selected.isEmpty || _loading ? null : _add,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryMid,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Save'.tr(context),
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ] else if (!_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No more employees to add'.tr(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              if (showRemove) const SizedBox(height: 4),
              if (showRemove) ...[
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (removable.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No members to remove'.tr(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  for (final m in removable) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        m.employee.name,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      subtitle: Text(
                        m.roleLabel,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: colors.textMuted,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: AppColors.error,
                        ),
                        onPressed: _loading
                            ? null
                            : () => _remove(m.employee.id),
                      ),
                    ),
                  ],
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════

TextStyle _muted(BuildContext context) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 13,
  color: context.appColors.textMuted,
);

Color _parseHexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}

DateTime? _parseYmd(String? y) {
  if (y == null || y.isEmpty) return null;
  return DateTime.tryParse(y);
}

String _formatYmd(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
