import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/theme/app_spacing.dart';

import '../controllers/global_error_handler.dart';
import '../controllers/paginated_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ═══════════════════════════════════════════════════════════════════
// Loading
// ═══════════════════════════════════════════════════════════════════

class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primaryMid,
            ),
          ),
          if (message != null) ...[
            AppSpacing.verticalMd,
            Text(message!,
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 13, color: context.appColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Error Full Screen
// ═══════════════════════════════════════════════════════════════════

class ErrorFullScreen extends StatelessWidget {
  final UiError error;
  final VoidCallback? onRetry;

  const ErrorFullScreen({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isOffline =
        error.action == ErrorAction.showFullScreen &&
        error.title == 'No connection';

    return Center(
      child: Padding(
        padding: AppSpacing.paddingAllXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),
            AppSpacing.verticalMd,
            Text(
              error.title.tr(context),
              style: TextStyle(fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.appColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalSm,
            Text(
              error.message.tr(context),
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 13, color: context.appColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (error.traceId != null) ...[
              AppSpacing.verticalXs,
              Text(
                'Trace: ${error.traceId}',
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11, color: context.appColors.textMuted),
              ),
            ],
            if (onRetry != null) ...[
              AppSpacing.verticalLg,
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryMid, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.navy,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Retry'.tr(context),
                        style: TextStyle(fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;

  const EmptyState(
      {super.key, this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingAllXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryMid.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 36,
                color: AppColors.primaryMid,
              ),
            ),
            AppSpacing.verticalMd,
            Text(
              title,
              style: TextStyle(fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.verticalSm,
              Text(
                subtitle!,
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 13, color: context.appColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Paginated List Builder
// ═══════════════════════════════════════════════════════════════════

class PaginatedListView<T> extends StatefulWidget {
  final PaginatedState<T> state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData? emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final Widget? header;

  const PaginatedListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
    this.header,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    if (s.isLoading) {
      return const LoadingIndicator();
    }

    if (s.error != null && !s.hasData) {
      return ErrorFullScreen(
        error: s.error!,
        onRetry: () => widget.onRefresh(),
      );
    }

    if (s.isEmpty) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
      );
    }

    final itemCount =
        s.items.length +
        (widget.header != null ? 1 : 0) +
        (s.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      color: AppColors.primaryMid,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Header
          if (widget.header != null && index == 0) {
            return widget.header!;
          }

          final dataIndex = index - (widget.header != null ? 1 : 0);

          // Loading more indicator
          if (dataIndex >= s.items.length) {
            return const Padding(
              padding: AppSpacing.paddingAllMd,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMid),
                ),
              ),
            );
          }

          return widget.itemBuilder(context, s.items[dataIndex]);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Session Expired Dialog
// ═══════════════════════════════════════════════════════════════════

class SessionExpiredDialog extends StatelessWidget {
  const SessionExpiredDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SessionExpiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_clock, size: 28, color: AppColors.gold),
      ),
      title: Text('Session expired'.tr(context),
          style: TextStyle(fontFamily: 'Cairo',fontWeight: FontWeight.w700)),
      content: Text(
          'Your session has expired. Please sign in again.'.tr(context),
          style: TextStyle(fontFamily: 'Cairo',color: context.appColors.textSecondary)),
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryMid, AppColors.primaryDeep],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              'Sign in'.tr(context),
              style: TextStyle(fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Cached Network Image
// ═══════════════════════════════════════════════════════════════════

class CacheImg extends StatelessWidget {
  final String url;
  final BoxFit? boxFit;
  final double? imgWidth;
  final double sizeCircleLoading;
  const CacheImg({
    super.key,
    required this.url,
    this.boxFit,
    this.imgWidth,
    this.sizeCircleLoading = 40,
  });

  @override
  Widget build(BuildContext context) {
    String imageUrl = "";

    if (url.trim().isEmpty) {
      imageUrl = "";
    } else if (url.startsWith("http")) {
      imageUrl = url;
    } else {
      imageUrl = "https://$url";
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: boxFit,
      width: imgWidth,
      placeholder: (context, url) {
        return Container(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: sizeCircleLoading,
                width: sizeCircleLoading,
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryMid),
              ),
            ],
          ),
        );
      },
      errorWidget: (context, url, error) {
        return Icon(
          Icons.error_outline,
          size: sizeCircleLoading,
          color: context.appColors.textMuted,
        );
      },
    );
  }
}
