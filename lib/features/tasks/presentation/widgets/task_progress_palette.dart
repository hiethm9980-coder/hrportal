import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';

/// Single source of truth for «what color does a progress bar use?».
///
/// Mirrors the server's auto-derive table so the bar's hue always agrees
/// with the status the server will compute / has computed:
///
/// ```
///   0           → red    (TODO / للتنفيذ)
///   1..69       → orange (IN_PROGRESS / قيد التنفيذ)
///   70..99      → blue   (REVIEW / قيد المراجعة)
///   100         → green  (DONE / مكتملة)
///   status=HOLD → purple (overrides percent-based color)
/// ```
///
/// `HOLD` is special because its progress can be 90 (when transitioning
/// from DONE) or any prior value, so coloring it by percent would be
/// misleading — purple wins as long as the task is on hold.
class TaskProgressPalette {
  TaskProgressPalette._();

  /// Purple reserved for `HOLD`. Picked to harmonize with the navy theme
  /// and stay clearly distinct from the gold/green/red/blue progress
  /// colors. Matches the server's status hex for HOLD closely enough to
  /// avoid clashing when both are visible side-by-side (status chip + bar).
  static const Color holdPurple = Color(0xFF8B5CF6);

  /// Resolve the bar/thumb color for a task whose [percent] is shown in
  /// the slider. Pass [statusCode] when known so HOLD wins over the
  /// percent-derived color; omit it for purely-numeric pickers (e.g. the
  /// "default progress" slider on the AI bulk-create screen).
  static Color forTask(int percent, {String? statusCode}) {
    if (statusCode == 'HOLD') return holdPurple;
    return forPercent(percent);
  }

  /// Pure-numeric variant — used when the caller is picking a progress
  /// value in isolation (no associated status). Matches the server's
  /// auto-derive ranges exactly.
  static Color forPercent(int percent) {
    final p = percent.clamp(0, 100);
    if (p >= 100) return AppColors.success;        // DONE
    if (p >= 70) return AppColors.primaryLight;    // REVIEW
    if (p >= 1) return AppColors.warning;          // IN_PROGRESS
    return AppColors.error;                        // TODO (0)
  }

  /// Color for a status chip. Maps the canonical 5 codes to the same
  /// palette the slider uses, so a chip and its sibling progress bar
  /// always agree on hue. Unknown codes (custom statuses configured on
  /// the server) fall back to [fallbackHex] so the customisation still
  /// shows — we never strip server-driven theming silently.
  ///
  /// Example:
  /// ```dart
  /// final color = TaskProgressPalette.forStatusCode(
  ///   'IN_PROGRESS',
  ///   fallbackHex: status.color, // server-provided hex
  /// );
  /// ```
  static Color forStatusCode(String? code, {String? fallbackHex}) {
    switch (code) {
      case 'DONE':
        return AppColors.success;
      case 'REVIEW':
        return AppColors.primaryLight;
      case 'IN_PROGRESS':
        return AppColors.warning;
      case 'TODO':
        return AppColors.error;
      case 'HOLD':
        return holdPurple;
    }
    if (fallbackHex != null && fallbackHex.trim().isNotEmpty) {
      return _parseHex(fallbackHex);
    }
    return const Color(0xFF6B7280); // neutral gray
  }

  /// Parse a `#RRGGBB` / `RRGGBB` / `AARRGGBB` string into a [Color].
  /// Defensive: invalid input returns a neutral gray rather than throwing
  /// (server hex coming back malformed shouldn't crash the UI).
  static Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    final parsed = int.tryParse(withAlpha, radix: 16);
    if (parsed == null) return const Color(0xFF6B7280);
    return Color(parsed);
  }
}
