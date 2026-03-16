import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/shared/widgets/shared_widgets.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';
import '../providers/notifications_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;

    const threshold = 220.0;
    final pos = _scrollCtrl.position;

    if (pos.pixels >= pos.maxScrollExtent - threshold) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete all notifications'.tr(context),
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        content: Text("Are you sure? This action can't be undone.".tr(context),
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr(context),
                style: GoogleFonts.cairo(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr(context), style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await ref.read(notificationsProvider.notifier).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return PopScope(
      canPop: !state.isSearchMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _searchCtrl.clear();
          notifier.closeSearch();
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            if (state.isSearchMode)
              _SearchHeader(
                controller: _searchCtrl,
                onBack: () {
                  _searchCtrl.clear();
                  notifier.closeSearch();
                  FocusScope.of(context).unfocus();
                },
                onClear: () {
                  _searchCtrl.clear();
                  notifier.clearSearch();
                },
                onChanged: notifier.onSearchChanged,
              )
            else
              _NormalHeader(
                unreadCount: state.unreadCount,
                onSearch: () {
                  _searchCtrl.text = state.searchText;
                  _searchCtrl.selection =
                      TextSelection.collapsed(offset: _searchCtrl.text.length);
                  notifier.openSearch();
                },
                onRefresh: notifier.refresh,
                onClearAll: () => _confirmClearAll(context),
              ),
            Expanded(child: _buildBody(context, state, notifier)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsState state,
      NotificationsNotifier notifier) {
    Future<void> onPullRefresh() async {
      await notifier.refresh();
    }

    // Initial loading
    if (state.isLoading && state.visible.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMid),
      );
    }

    // Empty
    if (state.visible.isEmpty) {
      final isSearch = state.searchText.trim().isNotEmpty;
      return RefreshIndicator(
        color: AppColors.primaryMid,
        onRefresh: onPullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: EmptyStateWidget(
                icon: '🔔',
                title: isSearch
                    ? 'No results'.tr(context)
                    : 'No notifications'.tr(context),
                subtitle: isSearch
                    ? 'Try different keywords'.tr(context)
                    : 'Notifications will appear here when they arrive.'
                        .tr(context),
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = state.visible.length + (state.isLoadingMore ? 1 : 0);
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();

    return RefreshIndicator(
      color: AppColors.primaryMid,
      onRefresh: onPullRefresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (state.isLoadingMore && index == state.visible.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMid),
                ),
              ),
            );
          }

          final n = state.visible[index];
          final titleText = n.titleByLang(lang);
          final bodyText = n.bodyByLang(lang);
          final dateText = AppFuns.formatDateTime(n.createdAtDate);

          final route = (n.route ?? '').trim();
          final url = (n.url ?? '').trim();
          final showActionIcon = route.isNotEmpty || url.isNotEmpty;

          Future<void> onTap() async {
            if (!n.isRead) {
              await notifier.markAsRead(n.id);
            }

            if (route.isNotEmpty) {
              final path = route.startsWith('/') ? route : '/$route';
              if (context.mounted) {
                context.push(path, extra: n.payload ?? const {});
              }
              return;
            }

            if (url.isNotEmpty && url.startsWith('http')) {
              await AppFuns.openUrl(url);
            }
          }

          return Slidable(
            key: ValueKey(n.id),
            endActionPane: ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.25,
              dismissible: DismissiblePane(
                motion: const BehindMotion(),
                closeOnCancel: true,
                confirmDismiss: () async {
                  final ok = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Text('Delete notification'.tr(context),
                              style:
                                  GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                          content: Text(
                            'Do you want to delete this notification?'
                                .tr(context),
                            style: GoogleFonts.cairo(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: Text('Cancel'.tr(context),
                                  style: GoogleFonts.cairo(
                                      color: AppColors.textMuted)),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: Text('Delete'.tr(context),
                                  style: GoogleFonts.cairo()),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  return ok;
                },
                onDismissed: () {
                  notifier.deleteById(n.id);
                },
              ),
              children: [
                CustomSlidableAction(
                  backgroundColor: AppColors.errorSoft,
                  foregroundColor: AppColors.error,
                  autoClose: false,
                  onPressed: (ctx) async {
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: Text('Delete notification'.tr(context),
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700)),
                            content: Text(
                              'Do you want to delete this notification?'
                                  .tr(context),
                              style: GoogleFonts.cairo(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: Text('Cancel'.tr(context),
                                    style: GoogleFonts.cairo(
                                        color: AppColors.textMuted)),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: Text('Delete'.tr(context),
                                    style: GoogleFonts.cairo()),
                              ),
                            ],
                          ),
                        ) ??
                        false;

                    if (!ok) {
                      if (ctx.mounted) Slidable.of(ctx)?.close();
                      return;
                    }

                    if (ctx.mounted) Slidable.of(ctx)?.close();
                    notifier.deleteById(n.id);
                  },
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 24),
                      child: Icon(Icons.delete_outline,
                          size: 24, color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
            child: _NotificationTile(
              titleText: titleText,
              bodyText: bodyText,
              dateText: dateText,
              img: n.img,
              isRead: n.isRead,
              showActionIcon: showActionIcon,
              onActionTap: showActionIcon ? onTap : null,
              onTap: onTap,
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Normal Header (gradient)
// ═══════════════════════════════════════════════════════════════════

class _NormalHeader extends StatelessWidget {
  const _NormalHeader({
    required this.onRefresh,
    required this.onSearch,
    required this.onClearAll,
    required this.unreadCount,
  });

  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final VoidCallback onClearAll;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryMid, AppColors.primaryDeep],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Title + badge
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Notifications'.tr(context),
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              _HeaderIconButton(
                icon: Icons.search_rounded,
                onTap: onSearch,
              ),
              const SizedBox(width: 6),
              _HeaderIconButton(
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
              const SizedBox(width: 6),
              _HeaderIconButton(
                icon: Icons.delete_sweep_outlined,
                onTap: onClearAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

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
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Search Header
// ═══════════════════════════════════════════════════════════════════

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.onBack,
    required this.onClear,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryMid, AppColors.primaryDeep],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.primaryMid),
                ),
                suffixIcon: IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                ),
                hintText: 'Search'.tr(context),
                hintStyle: GoogleFonts.cairo(color: AppColors.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Notification Tile
// ═══════════════════════════════════════════════════════════════════

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.titleText,
    required this.bodyText,
    required this.dateText,
    required this.img,
    required this.isRead,
    required this.showActionIcon,
    this.onActionTap,
    this.onTap,
  });

  final String titleText;
  final String bodyText;
  final String dateText;
  final String? img;
  final bool isRead;
  final bool showActionIcon;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppColors.bgCard : AppColors.primaryMid.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isRead ? AppShadows.sm : AppShadows.card,
          border: isRead
              ? null
              : Border.all(
                  color: AppColors.primaryMid.withOpacity(0.15), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img != null && img!.trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CacheImg(
                    url: img ?? '',
                    imgWidth: 56,
                    boxFit: BoxFit.cover,
                    sizeCircleLoading: 24),
              )
            else
              _CircleTypeIcon(isRead: isRead),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titleText,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bodyText,
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateText,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (showActionIcon)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: GestureDetector(
                  onTap: onActionTap,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMid.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.primaryMid),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleTypeIcon extends StatelessWidget {
  const _CircleTypeIcon({required this.isRead});
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isRead
            ? null
            : const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primaryMid],
              ),
        color: isRead ? AppColors.gray100 : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.notifications_none_rounded,
        size: 22,
        color: isRead ? AppColors.textMuted : Colors.white,
      ),
    );
  }
}
