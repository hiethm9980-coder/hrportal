import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// Static accent colors (same in light & dark)
// ═══════════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ── Primary Navy ──
  static const Color primaryDeep   = Color(0xFF071628);
  static const Color primary       = Color(0xFF0F2952);
  static const Color primaryMid    = Color(0xFF1A4080);
  static const Color primaryLight  = Color(0xFF2563B0);
  static const Color primarySoft   = Color(0xFFEBF2FB);
  static const Color primaryBorder = Color(0xFFC5D8F0);
  static const Color primaryGhost  = Color(0xFFF3F7FD);

  // ── Gold Accent ──
  static const Color gold      = Color(0xFFC69228);
  static const Color goldLight = Color(0xFFE3AC35);
  static const Color goldSoft  = Color(0xFFFBF5E4);
  static const Color goldDark  = Color(0xFF9A6F18);

  // ── Teal Accent ──
  static const Color teal      = Color(0xFF0A7A65);
  static const Color tealLight = Color(0xFF18A88C);
  static const Color tealSoft  = Color(0xFFE3F5F1);

  // ── Semantic ──
  static const Color success     = Color(0xFF059669);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF065F46);

  static const Color warning     = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);

  static const Color error     = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF991B1B);

  static const Color info     = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF1E40AF);

  // ── Gradients (same for both themes) ──
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryMid, primaryDeep],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDeep],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealLight, teal],
  );

  // ── Convenience: resolve theme-aware colors from context ──
  static AppColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<AppColorsExtension>()!;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Theme-aware colors (change between light & dark)
// ═══════════════════════════════════════════════════════════════════

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color bg;
  final Color bgCard;
  final Color bgSection;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color inputFill;
  final Color inputBorder;
  final Color divider;
  final Color cardBorder;

  // Grays
  final Color gray50;
  final Color gray100;
  final Color gray200;
  final Color gray300;
  final Color gray400;

  const AppColorsExtension({
    required this.bg,
    required this.bgCard,
    required this.bgSection,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.inputFill,
    required this.inputBorder,
    required this.divider,
    required this.cardBorder,
    required this.gray50,
    required this.gray100,
    required this.gray200,
    required this.gray300,
    required this.gray400,
  });

  // ── Light ──
  static const light = AppColorsExtension(
    bg: Color(0xFFF0F3FA),
    bgCard: Color(0xFFFFFFFF),
    bgSection: Color(0xFFF7F9FD),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF374151),
    textMuted: Color(0xFF6B7280),
    textDisabled: Color(0xFF9CA3AF),
    inputFill: Color(0xFFF9FAFB),
    inputBorder: Color(0xFFE5E7EB),
    divider: Color(0xFFF3F4F6),
    cardBorder: Colors.transparent,
    gray50: Color(0xFFF9FAFB),
    gray100: Color(0xFFF3F4F6),
    gray200: Color(0xFFE5E7EB),
    gray300: Color(0xFFD1D5DB),
    gray400: Color(0xFF9CA3AF),
  );

  // ── Dark ──
  static const dark = AppColorsExtension(
    bg: Color(0xFF0F1117),
    bgCard: Color(0xFF1A1D27),
    bgSection: Color(0xFF151821),
    textPrimary: Color(0xFFE8ECF4),
    textSecondary: Color(0xFFB0B8C8),
    textMuted: Color(0xFF727D92),
    textDisabled: Color(0xFF4A5568),
    inputFill: Color(0xFF1E2230),
    inputBorder: Color(0xFF2D3348),
    divider: Color(0xFF232838),
    cardBorder: Color(0xFF2D3348),
    gray50: Color(0xFF1A1D27),
    gray100: Color(0xFF232838),
    gray200: Color(0xFF2D3348),
    gray300: Color(0xFF3D4560),
    gray400: Color(0xFF5A6478),
  );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? bg, Color? bgCard, Color? bgSection,
    Color? textPrimary, Color? textSecondary, Color? textMuted, Color? textDisabled,
    Color? inputFill, Color? inputBorder, Color? divider, Color? cardBorder,
    Color? gray50, Color? gray100, Color? gray200, Color? gray300, Color? gray400,
  }) {
    return AppColorsExtension(
      bg: bg ?? this.bg,
      bgCard: bgCard ?? this.bgCard,
      bgSection: bgSection ?? this.bgSection,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      divider: divider ?? this.divider,
      cardBorder: cardBorder ?? this.cardBorder,
      gray50: gray50 ?? this.gray50,
      gray100: gray100 ?? this.gray100,
      gray200: gray200 ?? this.gray200,
      gray300: gray300 ?? this.gray300,
      gray400: gray400 ?? this.gray400,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(covariant ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgSection: Color.lerp(bgSection, other.bgSection, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      gray50: Color.lerp(gray50, other.gray50, t)!,
      gray100: Color.lerp(gray100, other.gray100, t)!,
      gray200: Color.lerp(gray200, other.gray200, t)!,
      gray300: Color.lerp(gray300, other.gray300, t)!,
      gray400: Color.lerp(gray400, other.gray400, t)!,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Extension on BuildContext for quick access
// ═══════════════════════════════════════════════════════════════════

extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>() ?? AppColorsExtension.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
