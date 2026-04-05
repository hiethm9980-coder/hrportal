import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

// ── Buttons ───────────────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final String? icon;
  final bool loading;
  final bool fullWidth;
  final bool small;

  const PrimaryButton({
    super.key, required this.text, this.onTap,
    this.icon, this.loading = false, this.fullWidth = true, this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: loading ? 0.75 : 1.0,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            vertical: small ? 10 : 14,
            horizontal: small ? 16 : 20,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primaryDeep],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            boxShadow: AppShadows.navy,
          ),
          child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Text(icon!, style: TextStyle(fontSize: small ? 14 : 16)),
                    const SizedBox(width: 6),
                  ],
                  Text(text, style: TextStyle(fontFamily: 'Cairo',
                    fontSize: small ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
                ],
              ),
        ),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final String? icon;
  final bool fullWidth;
  final bool small;

  const GoldButton({
    super.key, required this.text, this.onTap,
    this.icon, this.fullWidth = true, this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: small ? 10 : 13,
          horizontal: small ? 16 : 20,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: AppShadows.gold,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(icon!, style: TextStyle(fontSize: small ? 14 : 16)),
              const SizedBox(width: 6),
            ],
            Text(text, style: TextStyle(fontFamily: 'Cairo',
              fontSize: small ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            )),
          ],
        ),
      ),
    );
  }
}

class TealButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final String? icon;
  final bool fullWidth;
  final bool small;

  const TealButton({
    super.key, required this.text, this.onTap,
    this.icon, this.fullWidth = true, this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: small ? 10 : 13,
          horizontal: small ? 16 : 20,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.tealGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: AppShadows.teal,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(icon!, style: TextStyle(fontSize: small ? 14 : 16)),
              const SizedBox(width: 6),
            ],
            Text(text, style: TextStyle(fontFamily: 'Cairo',
              fontSize: small ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
          ],
        ),
      ),
    );
  }
}

class AppOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final bool fullWidth;
  final bool small;

  const AppOutlineButton({
    super.key, required this.text, this.onTap,
    this.color, this.fullWidth = true, this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryMid;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: small ? 9 : 12,
          horizontal: small ? 16 : 20,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: c, width: 1.5),
        ),
        child: Center(
          child: Text(text, style: TextStyle(fontFamily: 'Cairo',
            fontSize: small ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: c,
          )),
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String text;
  final String type; // success, warning, error, info, navy, gold, pending, approved, rejected, completed
  final bool dot;
  final String? icon;

  const StatusBadge({
    super.key, required this.text, required this.type,
    this.dot = false, this.icon,
  });

  (Color bg, Color fg) get _colors {
    switch (type) {
      case 'success':   case 'approved':  return (AppColors.successSoft, AppColors.successDark);
      case 'warning':   case 'pending':   return (AppColors.warningSoft, AppColors.warningDark);
      case 'error':     case 'rejected':  return (AppColors.errorSoft, AppColors.errorDark);
      case 'info':                        return (AppColors.infoSoft, AppColors.infoDark);
      case 'navy':      case 'completed': return (AppColors.primarySoft, AppColors.primaryMid);
      case 'gold':                        return (AppColors.goldSoft, AppColors.goldDark);
      default:                            return (const Color(0xFFF3F4F6), const Color(0xFF4B5563));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 5, height: 5,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[
            Text(icon!, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
          ],
          Text(text, style: TextStyle(fontFamily: 'Cairo',
            fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// ── App Card ──────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final double? padding;
  final double? marginBottom;
  final VoidCallback? onTap;
  final EdgeInsets? customPadding;

  const AppCard({
    super.key, required this.child, this.padding, this.marginBottom,
    this.onTap, this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: marginBottom ?? 0),
        padding: customPadding ?? EdgeInsets.all(padding ?? AppSpacing.cardPad),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );
  }
}

// ── Section Header (employ_portal style) ─────────────────

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key, required this.title, this.actionLabel, this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Cairo',
            fontSize: 16, fontWeight: FontWeight.w800,
            color: context.appColors.textPrimary,
          )),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel ?? 'View all', style: TextStyle(fontFamily: 'Cairo',
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.primaryMid,
              )),
            )
          else const SizedBox(),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? icon;
  final bool showBorder;

  const InfoRow({
    super.key, required this.label, required this.value,
    this.icon, this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showBorder ? Border(
          bottom: BorderSide(color: context.appColors.gray100),
        ) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(icon!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(fontFamily: 'Cairo',
                fontSize: 13, color: context.appColors.textMuted,
              )),
            ],
          ),
          Flexible(
            child: Text(value, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 13, fontWeight: FontWeight.w600, color: context.appColors.textSecondary,
            ), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ── Custom App Bar ────────────────────────────────────────

class CustomAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final Widget? leading;
  final Widget? trailing;
  final Widget? bottom;

  const CustomAppBar({
    super.key, required this.title, this.subtitle,
    this.onBack, this.onRefresh, this.leading, this.trailing, this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // ── Start side (right in RTL, left in LTR) ──
    Widget startWidget;
    if (leading != null) {
      startWidget = leading!;
    } else if (onBack != null) {
      startWidget = GestureDetector(
        onTap: onBack,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white, size: 18,
          ),
        ),
      );
    } else {
      startWidget = const SizedBox(width: 36);
    }

    // ── End side (left in RTL, right in LTR) ──
    final endWidgets = <Widget>[];
    if (onRefresh != null) {
      endWidgets.add(
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
          ),
        ),
      );
    }
    if (trailing != null) {
      if (endWidgets.isNotEmpty) endWidgets.add(const SizedBox(width: 6));
      endWidgets.add(trailing!);
    }

    Widget endWidget;
    if (endWidgets.isNotEmpty) {
      endWidget = Row(mainAxisSize: MainAxisSize.min, children: endWidgets);
    } else {
      endWidget = const SizedBox(width: 36);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryMid, AppColors.primaryDeep],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 18, right: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              startWidget,
              Expanded(
                child: Column(
                  children: [
                    Text(title, style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                    )),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 11, color: Colors.white60,
                      )),
                  ],
                ),
              ),
              endWidget,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 14),
            bottom!,
          ],
        ],
      ),
    );
  }
}

// ── Sticky Bottom Bar ─────────────────────────────────────

class StickyBottomBar extends StatelessWidget {
  final Widget child;

  const StickyBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18, offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 18, right: 18, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: child,
    );
  }
}

// ── Avatar Circle ─────────────────────────────────────────

class AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final Color? bg;
  final double? fontSize;

  const AvatarCircle({
    super.key, required this.initials, this.size = 44,
    this.bg, this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg ?? AppColors.primaryMid, AppColors.primaryDeep],
        ),
        shape: BoxShape.circle,
        boxShadow: AppShadows.sm,
      ),
      child: Center(
        child: Text(initials, style: TextStyle(fontFamily: 'Cairo',
          fontSize: fontSize ?? size * 0.35,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        )),
      ),
    );
  }
}

// ── Timeline Widget ───────────────────────────────────────

class TimelineStep {
  final String label;
  final String? subtitle;
  final bool isDone;
  final bool isActive;

  const TimelineStep({
    required this.label, this.subtitle,
    this.isDone = false, this.isActive = false,
  });
}

class TimelineWidget extends StatelessWidget {
  final List<TimelineStep> steps;

  const TimelineWidget({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((e) {
        final i = e.key; final s = e.value;
        final isLast = i == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.isDone ? AppColors.primaryMid
                        : s.isActive ? AppColors.gold
                        : context.appColors.gray200,
                    boxShadow: s.isActive ? AppShadows.gold : AppShadows.sm,
                  ),
                  child: Center(
                    child: s.isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(s.isActive ? '◉' : '${i+1}',
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: s.isDone || s.isActive ? Colors.white : context.appColors.gray400,
                          )),
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 28,
                    color: s.isDone ? AppColors.primarySoft : context.appColors.gray200),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(s.label, style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: s.isActive ? AppColors.primaryMid
                          : s.isDone ? context.appColors.textSecondary
                          : context.appColors.gray400,
                    )),
                    if (s.subtitle != null)
                      Text(s.subtitle!, style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 11, color: context.appColors.textMuted,
                      )),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Empty State ───────────────────────────────────────────

class EmptyStateWidget extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key, this.icon = '📂', required this.title,
    this.subtitle, this.actionLabel, this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 16, fontWeight: FontWeight.w700, color: context.appColors.textSecondary,
            ), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(fontFamily: 'Cairo',
                fontSize: 13, color: context.appColors.textMuted, height: 1.7,
              ), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(text: actionLabel!, onTap: onAction, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Toggle Switch ─────────────────────────────────────────

class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46, height: 27,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.primaryMid : context.appColors.gray300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
          child: Container(
            width: 21, height: 21,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter Tabs ───────────────────────────────────────────

class FilterTabs extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const FilterTabs({
    super.key, required this.tabs, required this.selected, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final isActive = e.key == selected;
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsetsDirectional.only(start: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryMid : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(e.value, style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : context.appColors.textMuted,
                )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Attachment Upload Box ─────────────────────────────────

class AttachmentUploadBox extends StatelessWidget {
  final VoidCallback? onTap;

  const AttachmentUploadBox({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryGhost,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBorder, width: 1.5),
        ),
        child: Column(
          children: [
            const Text('📎', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('انقر لإرفاق ملف', style: TextStyle(fontFamily: 'Cairo',
              fontSize: 13, color: context.appColors.textMuted,
            )),
            const SizedBox(height: 4),
            Text('PDF، JPG، PNG — حد أقصى 5MB', style: TextStyle(fontFamily: 'Cairo',
              fontSize: 11, color: context.appColors.gray400,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Loading Skeleton ──────────────────────────────────────

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90, margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(height: 12, width: 160, decoration: BoxDecoration(
            color: context.appColors.gray100, borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 8),
          Container(height: 10, width: 100, decoration: BoxDecoration(
            color: context.appColors.gray100, borderRadius: BorderRadius.circular(6))),
          const Spacer(),
          Container(height: 8, width: 60, decoration: BoxDecoration(
            color: context.appColors.gray100, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}
