import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'app_spacing.dart';

const String _fontFamily = 'Cairo';

/// Centralized app themes.
class AppTheme {
  AppTheme._();

  // ── Light Theme ──
  static final ThemeData light = _buildLightTheme();

  // ── Dark Theme ──
  static final ThemeData dark = _buildDarkTheme();

  // ═══════════════════════════════════════════════════════════
  // LIGHT
  // ═══════════════════════════════════════════════════════════

  static ThemeData _buildLightTheme() {
    const c = AppColorsExtension.light;

    final textTheme = TextTheme(
      displayLarge  : TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.3),
      displayMedium : TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3),
      displaySmall  : TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3),
      headlineLarge : TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.4),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.4),
      headlineSmall : TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.4),
      titleLarge    : TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.5),
      titleMedium   : TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.5),
      titleSmall    : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary, height: 1.5),
      bodyLarge     : TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.6),
      bodyMedium    : TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c.textSecondary, height: 1.6),
      bodySmall     : TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textMuted, height: 1.6),
      labelLarge    : TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.4),
      labelMedium   : TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted, height: 1.4),
      labelSmall    : TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textDisabled, height: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [AppColorsExtension.light],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        tertiary: AppColors.teal,
        surface: c.bgCard,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: c.bg,
      textTheme: textTheme,
      fontFamily: _fontFamily,

      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: AppColors.primaryMid,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: c.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryMid, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: TextStyle(fontFamily: _fontFamily, color: c.gray400, fontSize: 14),
        labelStyle: TextStyle(fontFamily: _fontFamily, color: c.textMuted, fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.bgCard,
        selectedItemColor: AppColors.primaryMid,
        unselectedItemColor: c.gray400,
        showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0, height: 72,
        backgroundColor: c.bgCard,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryMid);
          }
          return TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, color: c.gray400);
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        selectedLabelTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryMid),
        unselectedLabelTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: c.gray400),
      ),

      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 0),

      dialogTheme: DialogThemeData(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DARK
  // ═══════════════════════════════════════════════════════════

  static ThemeData _buildDarkTheme() {
    const c = AppColorsExtension.dark;

    final textTheme = TextTheme(
      displayLarge  : TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.3),
      displayMedium : TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3),
      displaySmall  : TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3),
      headlineLarge : TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.4),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.4),
      headlineSmall : TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.4),
      titleLarge    : TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.5),
      titleMedium   : TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.5),
      titleSmall    : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary, height: 1.5),
      bodyLarge     : TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.6),
      bodyMedium    : TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c.textSecondary, height: 1.6),
      bodySmall     : TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textMuted, height: 1.6),
      labelLarge    : TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.4),
      labelMedium   : TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted, height: 1.4),
      labelSmall    : TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textDisabled, height: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const [AppColorsExtension.dark],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.gold,
        tertiary: AppColors.tealLight,
        surface: c.bgCard,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: c.bg,
      textTheme: textTheme,
      fontFamily: _fontFamily,

      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: AppColors.primaryMid,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: c.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.cardBorder),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: TextStyle(fontFamily: _fontFamily, color: c.gray400, fontSize: 14),
        labelStyle: TextStyle(fontFamily: _fontFamily, color: c.textMuted, fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMid, foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: c.inputBorder),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.bgCard,
        selectedItemColor: AppColors.goldLight,
        unselectedItemColor: c.gray400,
        showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0, height: 72,
        backgroundColor: c.bgCard,
        indicatorColor: AppColors.primaryMid.withValues(alpha: 0.3),
        indicatorShape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.goldLight);
          }
          return TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, color: c.gray400);
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        selectedLabelTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.goldLight),
        unselectedLabelTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: c.gray400),
      ),

      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 0),

      dialogTheme: DialogThemeData(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
