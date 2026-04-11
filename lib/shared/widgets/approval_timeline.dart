import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/app_funs.dart';
import '../models/approval_models.dart';

// ═══════════════════════════════════════════════════════════════════
// Approval Timeline — shows every approver in the chain with state.
// Shared between the Employee Requests feature and the Leaves feature.
// ═══════════════════════════════════════════════════════════════════

/// Internal value object representing one merged stepper row.
///
/// Built by overlaying `approval_history` (the live state) on top of
/// `approval_chain` (the template). If a chain level has no history entry,
/// it means it was deactivated by a rule (e.g. `min_consecutive_days`) and
/// is rendered as "not required".
class _StepperEntry {
  final int level;
  final String title;
  final String? subtitle;
  final String state; // approved | rejected | current | waiting | inactive
  final String? decidedAt;
  final String? decidedByName;
  final String? notes;
  final String? activationRuleText;

  _StepperEntry({
    required this.level,
    required this.title,
    this.subtitle,
    required this.state,
    this.decidedAt,
    this.decidedByName,
    this.notes,
    this.activationRuleText,
  });
}

class ApprovalTimeline extends StatelessWidget {
  final List<ApprovalChainItem> chain;
  final List<ApprovalHistoryItem> history;
  final int? totalLevels;
  final int? currentLevel;

  const ApprovalTimeline({
    super.key,
    required this.chain,
    required this.history,
    this.totalLevels,
    this.currentLevel,
  });

  List<_StepperEntry> _buildEntries(bool isAr) {
    final byLevel = <int, ApprovalHistoryItem>{};
    for (final h in history) {
      byLevel[h.level] = h;
    }

    final levels = <int>{
      for (final c in chain) c.level,
      for (final h in history) h.level,
    }.toList()
      ..sort();

    ApprovalChainItem? chainAt(int lvl) {
      for (final c in chain) {
        if (c.level == lvl) return c;
      }
      return null;
    }

    final entries = <_StepperEntry>[];
    for (final lvl in levels) {
      final h = byLevel[lvl];
      final c = chainAt(lvl);

      if (h == null) {
        entries.add(_StepperEntry(
          level: lvl,
          title: c?.label.isNotEmpty == true ? c!.label : 'L$lvl',
          state: 'inactive',
          activationRuleText: c?.activationRuleText,
        ));
        continue;
      }

      final roleLabel = h.resolvedLabel(isAr);
      final approverName = h.approverName?.isNotEmpty == true
          ? h.approverName!
          : roleLabel;
      final subtitle =
          (roleLabel.isNotEmpty && roleLabel != approverName) ? roleLabel : null;

      String state;
      switch (h.decision) {
        case 'approved':
          state = 'approved';
          break;
        case 'rejected':
          state = 'rejected';
          break;
        default:
          state = h.isCurrent ? 'current' : 'waiting';
      }

      // Show "decided by ..." only when the actual decider differs from the
      // expected approver — typically when a higher-level manager bypasses the
      // chain.
      String? decidedByName;
      if ((h.decision == 'approved' || h.decision == 'rejected') &&
          (h.decidedByName != null && h.decidedByName!.isNotEmpty) &&
          h.decidedByName != h.approverName) {
        decidedByName = h.decidedByName;
      }

      entries.add(_StepperEntry(
        level: lvl,
        title: approverName.isEmpty ? 'L$lvl' : approverName,
        subtitle: subtitle,
        state: state,
        decidedAt: h.decidedAt,
        decidedByName: decidedByName,
        notes: h.notes,
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final entries = _buildEntries(isAr);
    if (entries.isEmpty) return const SizedBox.shrink();

    final total = totalLevels ?? entries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 18, color: AppColors.primaryMid),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Approval path'.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${currentLevel ?? entries.length} / $total',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++)
            _ApprovalTimelineRow(
              entry: entries[i],
              isLast: i == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ApprovalTimelineRow extends StatelessWidget {
  final _StepperEntry entry;
  final bool isLast;

  const _ApprovalTimelineRow({
    required this.entry,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String stateKey;
    switch (entry.state) {
      case 'approved':
        color = AppColors.success;
        icon = Icons.check_circle;
        stateKey = 'Approved';
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.cancel;
        stateKey = 'Rejected';
        break;
      case 'current':
        color = AppColors.warning;
        icon = Icons.hourglass_top;
        stateKey = 'Pending';
        break;
      case 'inactive':
        color = context.appColors.textMuted;
        icon = Icons.remove_circle_outline;
        stateKey = 'Not required';
        break;
      case 'waiting':
      default:
        color = context.appColors.textMuted;
        icon = Icons.radio_button_unchecked;
        stateKey = 'Pending';
    }

    final isMuted = entry.state == 'inactive' || entry.state == 'waiting';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stepper indicator column ──
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: entry.state == 'waiting' || entry.state == 'inactive'
                      ? Text(
                          '${entry.level}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        )
                      : Icon(icon, size: 18, color: color),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: entry.state == 'approved'
                        ? AppColors.success.withValues(alpha: 0.4)
                        : context.appColors.gray200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // ── Body ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 6 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isMuted
                                ? context.appColors.textMuted
                                : context.appColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stateKey.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle!,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                  if (entry.activationRuleText != null &&
                      entry.activationRuleText!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.activationRuleText!,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                  if (entry.decidedAt != null &&
                      entry.decidedAt!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 12, color: context.appColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(entry.decidedAt!),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: context.appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (entry.decidedByName != null &&
                      entry.decidedByName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: context.appColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${'Decided by'.tr(context)}: ${entry.decidedByName!}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: context.appColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote,
                              size: 14, color: color.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.notes!,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: context.appColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
}
