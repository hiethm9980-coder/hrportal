import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../../data/models/task_status_model.dart';
import '../../../providers/my_tasks_provider.dart' show TaskFilter;
import '../../../providers/subtasks_provider.dart';
import '../../../providers/task_statuses_provider.dart';
import '../../../widgets/advanced_filter_sheet.dart';
import '../../../widgets/task_card.dart';
import 'subtasks_parent_header.dart';

/// "Subtasks" tab of the task detail screen.
///
/// Header owns the parent-level status dropdown + progress input; body renders
/// child tasks via [TaskCard]. Tapping a subtask that itself has subtasks
/// pushes a nested detail screen (Lazy Loading tree).
class SubtasksTab extends ConsumerStatefulWidget {
  final int taskId;
  final String? initialTitle;

  const SubtasksTab({
    super.key,
    required this.taskId,
    this.initialTitle,
  });

  @override
  ConsumerState<SubtasksTab> createState() => _SubtasksTabState();
}

class _SubtasksTabState extends ConsumerState<SubtasksTab> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subtasksProvider(widget.taskId).notifier).load(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      ref.read(subtasksProvider(widget.taskId).notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      ref.read(subtasksProvider(widget.taskId).notifier).setSearch(value);
    });
  }

  void _toggleSearch() => setState(() => _showSearch = !_showSearch);

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(subtasksProvider(widget.taskId).notifier).setSearch('');
  }

  Future<void> _refresh() async {
    _searchController.clear();
    ref.invalidate(taskStatusesProvider);
    ref.read(subtasksProvider(widget.taskId).notifier)
      ..clearFilters(full: true)
      ..setSearch('');
  }

  Future<void> _openAdvancedFilters() async {
    final state = ref.read(subtasksProvider(widget.taskId));
    // The sheet wants a concrete [TaskFilter]; build one on the fly — only
    // the fields the sheet reads are populated.
    final adapted = TaskFilter(
      priorityCode: state.filter.priorityCode,
      overdueOnly: state.filter.overdueOnly,
      openOnly: state.filter.openOnly,
      dueFrom: state.filter.dueFrom,
      dueTo: state.filter.dueTo,
    );
    final result = await showAdvancedFilterSheet(context, current: adapted);
    if (result == null || !mounted) return;
    ref.read(subtasksProvider(widget.taskId).notifier).applyAdvancedFilters(
          priorityCode: result.priorityCode,
          overdueOnly: result.overdueOnly,
          openOnly: result.openOnly,
          dueFrom: result.dueFrom,
          dueTo: result.dueTo,
        );
  }

  Future<void> _changeStatus({
    required int taskId,
    required TaskStatus newStatus,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(subtasksProvider(widget.taskId).notifier)
          .updateStatus(taskId: taskId, statusCode: newStatus.code);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Status updated successfully'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  Future<void> _changeProgress({
    required int taskId,
    required int percent,
    required int previousPercent,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(subtasksProvider(widget.taskId).notifier)
          .updateProgress(
            taskId: taskId,
            percent: percent,
            previousPercent: previousPercent,
          );
      if (!mounted) return;
      if (result.statusChanged && result.isCompleted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Task marked as done'.tr(context),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subtasksProvider(widget.taskId));
    final statusesAsync = ref.watch(taskStatusesProvider);
    final allStatuses = statusesAsync.asData?.value ?? const <TaskStatus>[];
    final parentTitle = state.parent?.title ?? widget.initialTitle ?? '';

    return Stack(
      children: [
        Column(
          children: [
            SubtasksParentHeader(
              parentTitle: parentTitle,
              parent: state.parent,
              allStatuses: allStatuses,
              breakdown: state.statusBreakdown,
              selectedStatusCode: state.filter.statusCode,
              filtersActive: state.filter.hasAdvancedFilters,
              searchActive: state.filter.q.trim().isNotEmpty,
              showSearch: _showSearch,
              searchController: _searchController,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/my-tasks'),
              onRefresh: _refresh,
              onToggleSearch: _toggleSearch,
              onClearSearch: _clearSearch,
              onSearchChanged: _onSearchChanged,
              onStatusChipTap: (code) => ref
                  .read(subtasksProvider(widget.taskId).notifier)
                  .setStatus(code),
              onFilterTap: _openAdvancedFilters,
              onParentStatusChange: (s) {
                final parent = state.parent;
                if (parent == null) return;
                if (parent.status?.code == s.code) return;
                _changeStatus(taskId: parent.id, newStatus: s);
              },
              onParentProgressCommit: (percent) {
                final parent = state.parent;
                if (parent == null) return Future.value();
                final previous = parent.progressPercent ?? 0;
                return _changeProgress(
                  taskId: parent.id,
                  percent: percent,
                  previousPercent: previous,
                );
              },
            ),
            Expanded(
              child: _Body(
                state: state,
                allStatuses: allStatuses,
                scrollController: _scrollController,
                onRefresh: () => ref
                    .read(subtasksProvider(widget.taskId).notifier)
                    .load(reset: true),
                onChangeStatus: _changeStatus,
                onChangeProgress: _changeProgress,
              ),
            ),
          ],
        ),
        if (state.isMutating)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Updating status...'.tr(context),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Body
// ═══════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  final SubtasksState state;
  final List<TaskStatus> allStatuses;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function({required int taskId, required TaskStatus newStatus})
      onChangeStatus;
  final Future<void> Function({
    required int taskId,
    required int percent,
    required int previousPercent,
  }) onChangeProgress;

  const _Body({
    required this.state,
    required this.allStatuses,
    required this.scrollController,
    required this.onRefresh,
    required this.onChangeStatus,
    required this.onChangeProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.error != null && state.items.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRefresh);
    }
    if (state.items.isEmpty) {
      return _EmptyView(
        hasFilters: state.filter.hasAdvancedFilters ||
            state.filter.statusCode != null ||
            state.filter.q.isNotEmpty,
        onRetry: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final task = state.items[i];
          return TaskCard(
            task: task,
            allStatuses: allStatuses,
            onStatusChange: (newStatus) {
              if (task.status?.code == newStatus.code) return;
              onChangeStatus(taskId: task.id, newStatus: newStatus);
            },
            onProgressChange: onChangeProgress,
            onTap: () {
              // Lazy Loading tree: open a nested detail screen for this
              // subtask via go_router, so back navigation works and deep
              // links stay intact.
              context.push('/tasks/${task.id}', extra: task.title);
            },
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final Future<void> Function() onRetry;
  const _EmptyView({required this.hasFilters, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        children: [
          Icon(Icons.account_tree_outlined,
              size: 64, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No subtasks found'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try different filters'.tr(context)
                : 'This task has no subtasks yet'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryMid,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
