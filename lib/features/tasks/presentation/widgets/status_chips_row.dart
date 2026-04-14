import 'package:flutter/material.dart';

import 'package:hr_portal/core/localization/app_localizations.dart';
import '../../data/models/task_models.dart';

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
          color: _parseHex(s.color),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
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

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}
