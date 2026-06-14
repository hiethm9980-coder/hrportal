import 'package:flutter/material.dart';

import 'package:hr_portal/core/localization/app_localizations.dart';
import '../../data/models/task_models.dart';
import 'task_progress_palette.dart';

/// A horizontal row of status chips rendered in the dark header area.
///
/// Design matches the reference screenshot:
/// - Dark translucent card background.
/// - Large colored number on top (color comes from backend status).
/// - Label below in white/grey.
/// - Selected chip gets a brighter border and slightly lighter fill.
///
/// Counts come from the backend's `status_breakdown` and are NOT affected by
/// the currently selected status filter — so the user can freely hop
/// between chips without losing context.
class StatusChipsRow extends StatelessWidget {
  final StatusBreakdown breakdown;
  final String? selectedCode; // null => "All"
  final ValueChanged<String?> onChanged;

  const StatusChipsRow({
    super.key,
    required this.breakdown,
    required this.selectedCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _Chip(
        label: 'All'.tr(context),
        count: breakdown.all,
        color: Colors.white,
        selected: selectedCode == null,
        onTap: () => onChanged(null),
      ),
      ...breakdown.statuses.map(
        (s) => _Chip(
          label: s.label,
          count: s.count,
          // Drive the chip's accent color from the canonical palette so
          // the breakdown row shares hues with the slider + status chips
          // elsewhere. Server hex is kept as a fallback for any custom
          // statuses the team may add later.
          color: TaskProgressPalette.forStatusCode(
            s.code,
            fallbackHex: s.color,
          ),
          selected: selectedCode == s.code,
          onTap: () => onChanged(s.code),
        ),
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
        itemBuilder: (_, i) => chips[i],
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
    // AnimatedContainer يحمل لون/حد التحديد المتحرّك، و Material شفاف
    // فوقه يرسم الـ ripple عند الضغط على الـ chip.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 92,
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        ),
      ),
    );
  }
}

