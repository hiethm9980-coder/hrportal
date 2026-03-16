import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Navy ──────────────────────────────────────────
  static const Color primaryDeep   = Color(0xFF071628);
  static const Color primary       = Color(0xFF0F2952);
  static const Color primaryMid    = Color(0xFF1A4080);
  static const Color primaryLight  = Color(0xFF2563B0);
  static const Color primarySoft   = Color(0xFFEBF2FB);
  static const Color primaryBorder = Color(0xFFC5D8F0);
  static const Color primaryGhost  = Color(0xFFF3F7FD);

  // ── Gold Accent ───────────────────────────────────────────
  static const Color gold      = Color(0xFFC69228);
  static const Color goldLight = Color(0xFFE3AC35);
  static const Color goldSoft  = Color(0xFFFBF5E4);
  static const Color goldDark  = Color(0xFF9A6F18);

  // ── Teal Accent ───────────────────────────────────────────
  static const Color teal      = Color(0xFF0A7A65);
  static const Color tealLight = Color(0xFF18A88C);
  static const Color tealSoft  = Color(0xFFE3F5F1);

  // ── Backgrounds ───────────────────────────────────────────
  static const Color bg        = Color(0xFFF0F3FA);
  static const Color bgCard    = Color(0xFFFFFFFF);
  static const Color bgSection = Color(0xFFF7F9FD);

  // ── Neutral Gray ──────────────────────────────────────────
  static const Color gray50  = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // ── Semantic ──────────────────────────────────────────────
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

  // ── Text ──────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted     = Color(0xFF6B7280);
  static const Color textDisabled  = Color(0xFF9CA3AF);
  static const Color textOnDark    = Color(0xFFFFFFFF);

  // ── Gradients ─────────────────────────────────────────────
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
}
