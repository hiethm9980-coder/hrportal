import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/project_brief_model.dart';
import '../../data/models/task_models.dart';
import '../../data/models/task_status_model.dart';
import '../providers/company_list_scope_provider.dart';
import '../providers/my_tasks_provider.dart';
import '../providers/task_navigation_highlight_provider.dart';
import '../providers/projects_brief_provider.dart';
import '../providers/task_statuses_provider.dart';
import '../widgets/advanced_filter_sheet.dart';
import '../widgets/project_picker_sheet.dart';
import '../widgets/status_chips_row.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';

/// The "My Tasks" screen.
///
/// Default: [GET /api/v1/tasks] without `assignee_id` — tasks the server
/// returns for this user (assignee, task member, PM visibility, …). Optional
/// scope chip narrows to `assignee_id=me` only. Header: search, status chips,
/// project picker, advanced filters; infinite-scroll list body.
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();

    // [Riverpod] may still hold the last [TaskFilter.q] after the user
    // navigates away, but a fresh [TextEditingController] starts empty.
    // Rehydrate the search field from the provider so the visible string
    // matches the list that is still filtered.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final q = ref.read(myTasksProvider).filter.q;
      if (q.isNotEmpty) {
        _searchController.value = TextEditingValue(
          text: q,
          selection: TextSelection.collapsed(offset: q.length),
        );
        if (!_showSearch) {
          setState(() => _showSearch = true);
        }
      }
      final auth = ref.read(authProvider);
      if (auth.canFilterTasksByCompany) {
        final allowed = <int>{
          for (final c in auth.managedCompanies) c.id,
          if (auth.employee?.company != null) auth.employee!.company!.id,
        };
        await ref
            .read(companyListScopeIdProvider.notifier)
            .restoreIfAllowed(allowed);
      }
      if (!mounted) return;
      ref.read(myTasksProvider.notifier).load(reset: true);
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
      ref.read(myTasksProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      ref.read(myTasksProvider.notifier).setSearch(value);
    });
  }

  /// Toggle the visibility of the search field WITHOUT clearing any active
  /// query — collapsing the field simply hides it. If a query is still set,
  /// the search icon will render in gold to signal there's an active search.
  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
  }

  /// Clear the text inside the search field AND the underlying query.
  /// Keeps the search field visible so the user can immediately type again.
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(myTasksProvider.notifier).setSearch('');
  }

  Future<void> _refresh() async {
    _searchController.clear();
    // Invalidate caches so the next pick gets fresh projects/statuses too.
    ref.invalidate(taskStatusesProvider);
    ref.invalidate(projectsBriefProvider);
    ref.read(myTasksProvider.notifier)
      ..clearFilters(full: true)
      ..setSearch('');
  }

  Future<void> _openProjectPicker() async {
    final currentId = ref.read(myTasksProvider).filter.projectId;
    final result = await showProjectPickerSheet(
      context,
      selectedProjectId: currentId,
    );
    if (result == null || !mounted) return;

    if (result.openDetails && result.project != null) {
      context.push('/projects/${result.project!.id}/dashboard');
      return;
    }

    ref.read(myTasksProvider.notifier).setProject(result.project?.id);
  }

  Future<void> _openAdvancedFilters() async {
    final current = ref.read(myTasksProvider).filter;
    final values = await showAdvancedFilterSheet(context, current: current);
    if (values == null || !mounted) return;
    ref.read(myTasksProvider.notifier).applyAdvancedFilters(
          priorityCode: values.priorityCode,
          overdueOnly: values.overdueOnly,
          openOnly: values.openOnly,
          dueFrom: values.dueFrom,
          dueTo: values.dueTo,
          assigneeOnlyMe: values.assigneeOnlyMe,
        );
  }

  Future<void> _changeStatus({
    required int taskId,
    required TaskStatus newStatus,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myTasksProvider.notifier).updateStatus(
            taskId: taskId,
            statusCode: newStatus.code,
          );
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

  /// Commit a new progress value for a task via the dedicated progress
  /// endpoint. Deliberately does NOT reload the list — the provider
  /// does an optimistic in-place patch and the slider keeps its state.
  Future<void> _changeProgress({
    required int taskId,
    required int percent,
    required int previousPercent,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(myTasksProvider.notifier).updateProgress(
            taskId: taskId,
            percent: percent,
            previousPercent: previousPercent,
          );
      if (!mounted) return;
      // Only surface a snackbar for the auto-transition → DONE, so the user
      // understands why the status chip just changed. Regular drags stay
      // silent to avoid spamming notifications.
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
      rethrow; // let the slider roll back its local value
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myTasksProvider);
    final highlightTaskId = ref.watch(lastReturnedFromTaskDetailIdProvider);
    final auth = ref.watch(authProvider);
    final companyScope = ref.watch(companyListScopeIdProvider);
    final statusesAsync = ref.watch(taskStatusesProvider);
    final projectsAsync = ref.watch(projectsBriefProvider);

    // Resolve the selected project's name (for the dropdown-style button).
    final selectedProjectName = _selectedProjectName(
      selectedId: state.filter.projectId,
      projects: projectsAsync.asData?.value ?? const <ProjectBrief>[],
      fallback: 'All projects'.tr(context),
    );

    // When a project is selected, fetch its details to know whether the
    // current user is the project manager — that's the only role allowed
    // to create root tasks (2026-04 backend tightening). We hide the FAB
    // for everyone else. Loading / error → no FAB either, since the
    // server will reject the request anyway with a clear Arabic message.
    final activeProjectId = state.filter.projectId;
    final canCreateRootTask = activeProjectId != null &&
        (ref
                .watch(projectDetailsProvider(activeProjectId))
                .asData
                ?.value
                .permissions
                .canCreateTask ??
            false);

    final canPop = context.canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.mounted) context.go('/');
      },
      child: Scaffold(
      backgroundColor: context.appColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                showSearch: _showSearch,
                searchController: _searchController,
                breakdown: state.statusBreakdown,
                selectedStatusCode: state.filter.statusCode,
                selectedProjectName: selectedProjectName,
                projectActive: state.filter.projectId != null,
                filtersActive: state.filter.hasAdvancedFilters,
                searchActive: state.filter.q.trim().isNotEmpty,
                companyFilter: auth.canFilterTasksByCompany
                    ? _MyTasksCompanyScopeDropdown(
                        selectedId: companyScope,
                        onChanged: (v) async {
                          await ref
                              .read(companyListScopeIdProvider.notifier)
                              .setScope(v);
                          if (context.mounted) {
                            await ref
                                .read(myTasksProvider.notifier)
                                .load(reset: true);
                          }
                        },
                      )
                    : null,
                onBack: () => context.canPop() ? context.pop() : context.go('/'),
                onToggleSearch: _toggleSearch,
                onClearSearch: _clearSearch,
                onRefresh: _refresh,
                onSearchChanged: _onSearchChanged,
                onStatusTap: (code) =>
                    ref.read(myTasksProvider.notifier).setStatus(code),
                onProjectTap: _openProjectPicker,
                onFilterTap: _openAdvancedFilters,
              ),
              Expanded(
                child: _Body(
                  state: state,
                  highlightTaskId: highlightTaskId,
                  showTaskCompanyName: auth.canFilterTasksByCompany,
                  statusesAsync: statusesAsync,
                  scrollController: _scrollController,
                  onRefresh: () async {
                    await ref
                        .read(myTasksProvider.notifier)
                        .load(reset: true);
                  },
                  onChangeStatus: _changeStatus,
                  onChangeProgress: _changeProgress,
                  onOpenTask: (task) async {
                    await context.push('/tasks/${task.id}', extra: task.title);
                    if (!mounted) return;
                    ref
                        .read(lastReturnedFromTaskDetailIdProvider.notifier)
                        .state = task.id;
                  },
                ),
              ),
            ],
          ),
          // Full-screen mutation loader.
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
      ),
      // ── Add-task FAB ────────────────────────────────────────────────
      // Visible only when:
      //   1. the user has filtered by a specific project (otherwise the
      //      endpoint doesn't know where to create the task), AND
      //   2. the current user is the project manager (server enforces
      //      this; the `permissions.can_create_task` flag from the project
      //      detail endpoint tells us whether to surface the button).
      // Tapping the project name chip in the header opens the picker
      // which doubles as the "choose project first" entry point.
      floatingActionButton: canCreateRootTask
          ? FloatingActionButton.extended(
              heroTag: 'my-tasks-add-fab',
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
              onPressed: () async {
                final pid = state.filter.projectId;
                if (pid == null) return;
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddTaskScreen(
                      mode: AddTaskMode.project,
                      projectId: pid,
                      projectName: selectedProjectName,
                    ),
                  ),
                );
                if (created == true) {
                  ref.read(myTasksProvider.notifier).load(reset: true);
                }
              },
              icon: const Icon(Icons.add_task_rounded),
              label: Text(
                'Add task'.tr(context),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    ),
    );
  }

  String _selectedProjectName({
    required int? selectedId,
    required List<ProjectBrief> projects,
    required String fallback,
  }) {
    if (selectedId == null) return fallback;
    final match = projects.cast<ProjectBrief?>().firstWhere(
          (p) => p?.id == selectedId,
          orElse: () => null,
        );
    return match?.name ?? fallback;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final bool showSearch;
  final TextEditingController searchController;
  final dynamic breakdown; // StatusBreakdown from model — typed via use site
  final String? selectedStatusCode;
  final String selectedProjectName;
  final bool projectActive;
  final bool filtersActive;
  final bool searchActive;
  final Widget? companyFilter;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusTap;
  final VoidCallback onProjectTap;
  final VoidCallback onFilterTap;

  const _Header({
    required this.showSearch,
    required this.searchController,
    required this.breakdown,
    required this.selectedStatusCode,
    required this.selectedProjectName,
    required this.projectActive,
    required this.filtersActive,
    required this.searchActive,
    this.companyFilter,
    required this.onBack,
    required this.onToggleSearch,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.onStatusTap,
    required this.onProjectTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.navyGradient,
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 14,
        right: 14,
      ),
      child: Column(
        children: [
          // ── Row 1: Back / title / search / refresh ──────────────────
          Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'My Tasks'.tr(context),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              _IconBtn(
                icon: showSearch
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.search_rounded,
                // Show gold only when the field is collapsed AND a query is
                // still active — a visual hint that results are filtered by
                // search even though the input is hidden.
                active: !showSearch && searchActive,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),
          // ── Optional search field ─────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: showSearch
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchController,
                        builder: (_, value, _) {
                          final hasText = value.text.isNotEmpty;
                          return TextFormField(
                            controller: searchController,
                            autofocus: true,
                            onChanged: onSearchChanged,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              // Force transparent background — override any
                              // global InputDecorationTheme that sets filled.
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              hintText:
                                  'Search in your tasks...'.tr(context),
                              hintStyle: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 18,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 34, minHeight: 34),
                              suffixIcon: hasText
                                  ? GestureDetector(
                                      onTap: onClearSearch,
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            right: 4, left: 4),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withOpacity(0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(
                                  minWidth: 30, minHeight: 30),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (companyFilter != null) ...[
            const SizedBox(height: 10),
            companyFilter!,
          ],
          const SizedBox(height: 12),

          // ── Row 2: Status chips ───────────────────────────────────
          StatusChipsRow(
            breakdown: breakdown,
            selectedCode: selectedStatusCode,
            onChanged: onStatusTap,
          ),
          const SizedBox(height: 10),

          // ── Row 3: Project dropdown + filter icon ─────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onProjectTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: projectActive
                          ? AppColors.gold
                          : Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: projectActive
                            ? AppColors.gold
                            : Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_copy_outlined,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedProjectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down_rounded,
                            color: Colors.white.withOpacity(0.9)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: filtersActive
                        ? AppColors.gold
                        : Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: filtersActive
                          ? AppColors.gold
                          : Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 20),
                      if (filtersActive)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Body
// ═══════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  final MyTasksState state;
  final int? highlightTaskId;
  final bool showTaskCompanyName;
  final AsyncValue<List<TaskStatus>> statusesAsync;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function({required int taskId, required TaskStatus newStatus})
      onChangeStatus;
  final Future<void> Function({
    required int taskId,
    required int percent,
    required int previousPercent,
  }) onChangeProgress;
  final Future<void> Function(Task task) onOpenTask;

  const _Body({
    required this.state,
    this.highlightTaskId,
    this.showTaskCompanyName = false,
    required this.statusesAsync,
    required this.scrollController,
    required this.onRefresh,
    required this.onChangeStatus,
    required this.onChangeProgress,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    // Initial loading (no cached items yet) → full-screen spinner.
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Fatal error with no cached items → full-screen error.
    if (state.error != null && state.items.isEmpty) {
      return _ErrorView(
        message: state.error!,
        onRetry: onRefresh,
      );
    }

    if (state.items.isEmpty) {
      return _EmptyView(
        hasFilters:
            state.filter.hasAdvancedFilters ||
                state.filter.projectId != null ||
                state.filter.statusCode != null ||
                state.filter.q.isNotEmpty,
        onRetry: onRefresh,
      );
    }

    final allStatuses = statusesAsync.asData?.value ?? const <TaskStatus>[];

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
            showCompanyName: showTaskCompanyName,
            highlightAfterReturn: highlightTaskId == task.id,
            onStatusChange: (newStatus) {
              // Ignore if user tapped the same status.
              if (task.status?.code == newStatus.code) return;
              onChangeStatus(taskId: task.id, newStatus: newStatus);
            },
            onProgressChange: onChangeProgress,
            onTap: () => onOpenTask(task),
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
          Icon(Icons.task_alt_rounded,
              size: 64, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No tasks found'.tr(context),
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
                : "You don't have any tasks yet".tr(context),
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

/// [GET /tasks?company_id=] and project picker: scope for company managers.
class _MyTasksCompanyScopeDropdown extends ConsumerWidget {
  const _MyTasksCompanyScopeDropdown({
    required this.selectedId,
    required this.onChanged,
  });

  final int? selectedId;
  final Future<void> Function(int? v) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final byId = <int, String>{};
    for (final c in auth.managedCompanies) {
      byId.putIfAbsent(c.id, () => c.name);
    }
    final em = auth.employee?.company;
    if (em != null) {
      byId.putIfAbsent(em.id, () => em.name);
    }
    final ordered = <int>[];
    for (final c in auth.managedCompanies) {
      if (!ordered.contains(c.id)) ordered.add(c.id);
    }
    if (em != null && !ordered.contains(em.id)) ordered.add(em.id);

    final isValid = selectedId == null ||
        (selectedId != null && byId.containsKey(selectedId!));
    final value = isValid ? selectedId : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            isExpanded: true,
            value: value,
            isDense: true,
            borderRadius: BorderRadius.circular(10),
            dropdownColor: const Color(0xFF1a2a4a),
            icon: Icon(Icons.apartment_outlined, color: Colors.white.withValues(alpha: 0.9), size: 20),
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('All my companies'.tr(context)),
              ),
              for (final id in ordered)
                DropdownMenuItem<int?>(
                  value: id,
                  child: Text(
                    byId[id] ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v == selectedId) return;
              unawaited(onChanged(v));
            },
          ),
        ),
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
