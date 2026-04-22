import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/errors/exceptions.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/features/auth/presentation/providers/auth_providers.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../data/models/create_task_request.dart';
import '../../data/models/project_team_models.dart';
import '../../data/models/task_status_model.dart';
import '../providers/project_team_provider.dart';
import '../providers/task_statuses_provider.dart';

/// Which flavor of task are we creating?
///
/// - [project] → POST /projects/{projectId}/tasks (root task).
/// - [subtask] → POST /tasks/{parentTaskId}/subtasks.
///
/// Drives the subtitle in the header (project name vs parent task title) and
/// which repository method is called on submit.
enum AddTaskMode { project, subtask }

/// Full-screen task creation form.
///
/// Supports both "add to project" and "add as subtask" flows via [mode]. The
/// two flows are structurally identical — only the POST endpoint and the
/// header subtitle change.
class AddTaskScreen extends ConsumerStatefulWidget {
  final AddTaskMode mode;

  /// Always required — used for the team fetch and (in [AddTaskMode.project])
  /// as the POST URL component.
  final int projectId;

  /// Shown in the header subtitle when [mode] is [AddTaskMode.project]. When
  /// null the header shows only the "Add task" title.
  final String? projectName;

  /// Required when [mode] is [AddTaskMode.subtask] — the parent task's id
  /// becomes the POST URL component.
  final int? parentTaskId;

  /// Shown in the header subtitle when [mode] is [AddTaskMode.subtask].
  final String? parentTaskTitle;

  /// Employee id of the parent task's assignee. Only meaningful when [mode]
  /// is [AddTaskMode.subtask] — used to tag that person in the "Team
  /// members" list with a "Parent task assignee" subtitle so the creator
  /// knows who owns the task above this one.
  final int? parentAssigneeId;

  /// Called when the user taps the back button. When provided the screen
  /// does NOT call `Navigator.pop` — the host widget is expected to close
  /// its own overlay. Used for the in-tree overlay embedding inside the
  /// task detail shell so the shell's bottom nav stays visible.
  final VoidCallback? onClose;

  /// Called after a task has been created successfully. Has the same
  /// "host handles closing" semantics as [onClose].
  final VoidCallback? onCreated;

  /// True when the screen is rendered as an overlay inside a parent tab
  /// rather than as a standalone route.
  bool get isEmbedded => onClose != null || onCreated != null;

  const AddTaskScreen({
    super.key,
    required this.mode,
    required this.projectId,
    this.projectName,
    this.parentTaskId,
    this.parentTaskTitle,
    this.parentAssigneeId,
    this.onClose,
    this.onCreated,
  }) : assert(
          mode == AddTaskMode.project || parentTaskId != null,
          'parentTaskId is required when mode is subtask',
        );

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtl = ScrollController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // ── FormField keys — let us ask each validated field `.hasError`
  // directly after `validate()` runs, without re-implementing the
  // validator logic.
  final _titleFieldKey = GlobalKey<FormFieldState<String>>();
  final _descFieldKey = GlobalKey<FormFieldState<String>>();

  // ── Section keys — attached to each field's outer wrapper so we can
  // call `Scrollable.ensureVisible` on the first erroring section.
  // Order matches the visual top-to-bottom order.
  final _fieldKeys = <String, GlobalKey>{
    'title': GlobalKey(debugLabel: 'field_title'),
    'description': GlobalKey(debugLabel: 'field_description'),
    'status': GlobalKey(debugLabel: 'field_status'),
    'priority': GlobalKey(debugLabel: 'field_priority'),
    'due_date': GlobalKey(debugLabel: 'field_due_date'),
    'progress_percent': GlobalKey(debugLabel: 'field_progress'),
    'assignee_employee_id': GlobalKey(debugLabel: 'field_assignee'),
    'members': GlobalKey(debugLabel: 'field_members'),
  };

  /// Errors returned by the server's validation response, keyed by field
  /// name (matches what `ApiException.fieldErrors` produces). We keep the
  /// first message per field; validators prefer it over the local rules
  /// so the user sees the authoritative server-side message.
  final _serverErrors = <String, String>{};

  // Status / priority / due / progress local state.
  String? _statusCode; // null → server default (TODO)
  String _priorityCode = 'MEDIUM';
  DateTime _dueDate = DateTime.now();
  int _progress = 0;

  // Members + assignee selection.
  final Set<int> _memberIds = {};
  int? _assigneeId;

  /// Client-side "missing assignee" flag for the manager dropdown. This
  /// isn't a `TextFormField`, so we track its validation state explicitly
  /// and render an inline error under it when true.
  bool _assigneeMissing = false;

  // Calendar UI state — the format is locked to month view, so we only
  // need the currently-focused day.
  DateTime _focusedDay = DateTime.now();

  bool _submitting = false;

  @override
  void dispose() {
    _scrollCtl.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ── Derived ─────────────────────────────────────────────────────────

  int? get _currentEmployeeId =>
      ref.read(authProvider).employee?.id;

  bool _isCurrentUserManager(ProjectTeamData team) {
    final myId = _currentEmployeeId;
    return myId != null && team.managerId == myId;
  }

  /// Project manager **or** company manager (`managed_companies`): must pick
  /// [assignee_employee_id] from the project team when creating tasks so the
  /// server assigns someone in the task's company (see POST …/subtasks notes).
  bool _effectiveCanPickAssignee(ProjectTeamData team) {
    if (_isCurrentUserManager(team)) return true;
    return ref.read(authProvider).canFilterTasksByCompany;
  }

  // ── Submit ─────────────────────────────────────────────────────────

  /// Shows a short validation error as a snack bar. Used for validation
  /// checks that don't map to a single `TextFormField` (e.g. missing
  /// assignee, missing priority) where inline field errors aren't an
  /// option.
  void _showValidationSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Whether the given field currently has an error — either from the
  /// server ([_serverErrors]) or from the local form state.
  bool _fieldHasError(String name, {required bool canPickAssignee}) {
    if (_serverErrors.containsKey(name)) return true;
    switch (name) {
      case 'title':
        return _titleFieldKey.currentState?.hasError ?? false;
      case 'description':
        return _descFieldKey.currentState?.hasError ?? false;
      case 'assignee_employee_id':
        // PM / company manager must pick an assignee in the team list.
        return canPickAssignee && _assigneeMissing;
      default:
        // status/priority/due_date/progress/members are only flagged by
        // the server — no client-side validators.
        return false;
    }
  }

  /// Scroll the form to the first field (in display order) that currently
  /// has an error. No-op if nothing is invalid.
  Future<void> _scrollToFirstError({required bool canPickAssignee}) async {
    for (final entry in _fieldKeys.entries) {
      if (!_fieldHasError(entry.key, canPickAssignee: canPickAssignee)) continue;
      final ctx = entry.value.currentContext;
      if (ctx == null) return;
      // `alignment: 0.1` puts the target near the top of the viewport
      // (rather than centered) so the user sees both the field and its
      // error message without having to scan down.
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
  }

  Future<void> _submit(ProjectTeamData team) async {
    if (_submitting) return;

    final canPickAssignee = _effectiveCanPickAssignee(team);

    // Reset any prior server errors — the user is trying again.
    if (_serverErrors.isNotEmpty) {
      setState(() => _serverErrors.clear());
    }

    // ── 1. Local validation ────────────────────────────────────────
    // PM / company manager must send `assignee_employee_id` from the team list.
    final assigneeMissing = canPickAssignee && _assigneeId == null;
    if (_assigneeMissing != assigneeMissing) {
      setState(() => _assigneeMissing = assigneeMissing);
    }

    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || assigneeMissing) {
      await _scrollToFirstError(canPickAssignee: canPickAssignee);
      if (!mounted) return;
      _showValidationSnack(
          'Please correct the highlighted fields'.tr(context));
      return;
    }

    // Priority and status are always pre-selected (constructor + first
    // status from the server). Guard anyway to turn a silent 422 from
    // the server into a clear message before we hit the network.
    if (_priorityCode.isEmpty) {
      _showValidationSnack('Please select a priority'.tr(context));
      return;
    }

    // ── 2. Build body + send ───────────────────────────────────────
    final body = CreateTaskRequest(
      title: _titleController.text,
      description: _descController.text,
      priority: _priorityCode,
      status: _statusCode,
      progressPercent: _progress,
      dueDate: _formatDate(_dueDate),
      // Regular members don't send assignee — server forces it to the creator.
      assigneeEmployeeId: canPickAssignee ? _assigneeId : null,
      members: _memberIds.toList(),
    );

    setState(() => _submitting = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      if (widget.mode == AddTaskMode.subtask) {
        await repo.createSubtask(widget.parentTaskId!, body);
      } else {
        await repo.createRootTask(widget.projectId, body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task created successfully'.tr(context)),
          backgroundColor: AppColors.success,
        ),
      );
      if (widget.onCreated != null) {
        widget.onCreated!();
      } else {
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (e) {
      // ── 3. Server-side field errors ──────────────────────────────
      // Pull the per-field messages out of the exception and attach
      // them to the corresponding UI fields. After re-running the form
      // validators the inline errors appear automatically; then scroll
      // to the first invalid one and surface the summary snack bar.
      if (!mounted) return;
      setState(() {
        _serverErrors.clear();
        e.fieldErrors.forEach((field, errs) {
          if (errs.isNotEmpty) _serverErrors[field] = errs.first;
        });
      });
      _formKey.currentState?.validate();
      await _scrollToFirstError(canPickAssignee: canPickAssignee);
      if (!mounted) return;
      // Use the server-provided Arabic summary when it exists; otherwise
      // fall back to the generic client message.
      _showValidationSnack(
        e.message.isNotEmpty
            ? e.message
            : 'Please correct the highlighted fields'.tr(context),
      );
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final teamAsync = ref.watch(projectTeamProvider(widget.projectId));
    final statusesAsync = ref.watch(taskStatusesProvider);
    final allStatuses = statusesAsync.asData?.value ?? const <TaskStatus>[];

    // Pre-select the first status (typically "TODO / للتنفيذ") on first load
    // so the dropdown never renders in a blank "Set status" state.
    _ensureDefaultStatus(allStatuses);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _Header(
            titleKey: widget.mode == AddTaskMode.subtask
                ? 'New subtask'
                : 'New task',
            subtitle: widget.mode == AddTaskMode.subtask
                ? (widget.parentTaskTitle ?? '')
                : (widget.projectName ?? ''),
            onBack: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          Expanded(
            child: teamAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(projectTeamProvider(widget.projectId)),
              ),
              data: (team) {
                // First build: pre-select the current user as assignee when
                // they're a team member (both managers and regular members).
                _ensureDefaultAssignee(team);
                final canPickAssignee = _effectiveCanPickAssignee(team);
                return Form(
                  key: _formKey,
                  // `onUserInteraction` lets a field flag errors as soon as
                  // the user touches and leaves it invalid, instead of
                  // waiting for the final Save tap. Much friendlier than
                  // silently failing on submit.
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  // `SingleChildScrollView + Column` over `ListView`: every
                  // field stays in the tree regardless of scroll position,
                  // which makes `Scrollable.ensureVisible` + field-level
                  // GlobalKeys 100% reliable for scroll-to-error (ListView
                  // viewport culling can occasionally drop an offscreen
                  // child's context, and for a small fixed-size form the
                  // eager build has no meaningful cost).
                  child: SingleChildScrollView(
                    controller: _scrollCtl,
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Each field section is wrapped in a KeyedSubtree so
                      // `_scrollToFirstError()` can ensure-visible the
                      // offending section when validation fails.
                      KeyedSubtree(
                        key: _fieldKeys['title'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(
                                label: 'Title'.tr(context), required: true),
                            const SizedBox(height: 6),
                            _titleField(colors),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      KeyedSubtree(
                        key: _fieldKeys['description'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Description'.tr(context)),
                            const SizedBox(height: 6),
                            _descriptionField(colors),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Row 1: status + priority ─────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: KeyedSubtree(
                              key: _fieldKeys['status'],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(label: 'Status'.tr(context)),
                                  const SizedBox(height: 6),
                                  _statusDropdown(colors, allStatuses),
                                  if (_serverErrors['status'] != null)
                                    _InlineError(
                                        message: _serverErrors['status']!),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: KeyedSubtree(
                              key: _fieldKeys['priority'],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(
                                      label: 'Priority'.tr(context)),
                                  const SizedBox(height: 6),
                                  _priorityDropdown(colors),
                                  if (_serverErrors['priority'] != null)
                                    _InlineError(
                                        message: _serverErrors['priority']!),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: _fieldKeys['due_date'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Due date'.tr(context)),
                            const SizedBox(height: 6),
                            _dueDateCalendar(colors),
                            if (_serverErrors['due_date'] != null)
                              _InlineError(
                                  message: _serverErrors['due_date']!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: _fieldKeys['progress_percent'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(
                                label:
                                    '${'Progress'.tr(context)} — $_progress%'),
                            const SizedBox(height: 6),
                            _progressSlider(),
                            if (_serverErrors['progress_percent'] != null)
                              _InlineError(
                                  message:
                                      _serverErrors['progress_percent']!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Assignee first — decides who owns the task, so the
                      // creator should resolve it before picking extra
                      // helpers (team members).
                      KeyedSubtree(
                        key: _fieldKeys['assignee_employee_id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Assignee'.tr(context)),
                            const SizedBox(height: 6),
                            canPickAssignee
                                ? _assigneeDropdown(colors, team)
                                : _assigneeLocked(colors, team),
                            if (_serverErrors['assignee_employee_id'] != null)
                              _InlineError(
                                  message: _serverErrors[
                                      'assignee_employee_id']!)
                            else if (canPickAssignee && _assigneeMissing)
                              _InlineError(
                                  message: 'Please pick an assignee'
                                      .tr(context)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _fieldKeys['members'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(
                                label: 'Team members'.tr(context)),
                            const SizedBox(height: 8),
                            _memberList(colors, team),
                            if (_serverErrors['members'] != null)
                              _InlineError(
                                  message: _serverErrors['members']!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _submitButton(team),
                    ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Field builders ─────────────────────────────────────────────────

  Widget _titleField(AppColorsExtension colors) {
    return TextFormField(
      key: _titleFieldKey,
      controller: _titleController,
      textInputAction: TextInputAction.next,
      maxLength: 500,
      decoration: _inputDecoration(
        colors: colors,
        hint: 'Task title'.tr(context),
      ).copyWith(counterText: ''),
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700),
      // Typing in a field that had a server error should clear it — the
      // user is actively fixing the issue, so don't keep yelling.
      onChanged: (_) => _clearServerErrorFor('title'),
      validator: (v) {
        // Server-side errors take precedence: the backend already knows
        // its own business rules and ships localized Arabic messages.
        final server = _serverErrors['title'];
        if (server != null) return server;

        final s = (v ?? '').trim();
        if (s.isEmpty) {
          return 'Please enter the task title'.tr(context);
        }
        if (s.length < 3) {
          return 'Title must be at least 3 characters'.tr(context);
        }
        if (s.length > 500) {
          return 'Title must not exceed 500 characters'.tr(context);
        }
        return null;
      },
    );
  }

  Widget _descriptionField(AppColorsExtension colors) {
    return TextFormField(
      key: _descFieldKey,
      controller: _descController,
      minLines: 3,
      maxLines: 6,
      maxLength: 5000,
      decoration: _inputDecoration(
        colors: colors,
        hint: 'Describe the task...'.tr(context),
      ).copyWith(counterText: ''),
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      onChanged: (_) => _clearServerErrorFor('description'),
      validator: (v) {
        final server = _serverErrors['description'];
        if (server != null) return server;
        // Description is optional — only validate length when provided.
        final s = (v ?? '').trim();
        if (s.isEmpty) return null;
        if (s.length > 5000) {
          return 'Description must not exceed 5000 characters'.tr(context);
        }
        return null;
      },
    );
  }

  /// Remove a single server error on user interaction with the field.
  void _clearServerErrorFor(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors.remove(field));
  }

  Widget _statusDropdown(
      AppColorsExtension colors, List<TaskStatus> statuses) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(colors),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _statusCode,
          hint: Text(
            'Set status'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
          items: [
            for (final s in statuses)
              DropdownMenuItem<String?>(
                value: s.code,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _parseHex(s.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.label,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _statusCode = v),
        ),
      ),
    );
  }

  Widget _priorityDropdown(AppColorsExtension colors) {
    const options = [
      ('LOW', '#10B981'),
      ('MEDIUM', '#3B82F6'),
      ('HIGH', '#F59E0B'),
      ('CRITICAL', '#EF4444'),
    ];
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(colors),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _priorityCode,
          items: [
            for (final (code, color) in options)
              DropdownMenuItem<String>(
                value: code,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _parseHex(color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _priorityLabel(code),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _priorityCode = v ?? 'MEDIUM'),
        ),
      ),
    );
  }

  String _priorityLabel(String code) {
    switch (code) {
      case 'LOW':
        return 'Low'.tr(context);
      case 'HIGH':
        return 'High'.tr(context);
      case 'CRITICAL':
        return 'Critical'.tr(context);
      case 'MEDIUM':
      default:
        return 'Medium'.tr(context);
    }
  }

  Widget _dueDateCalendar(AppColorsExtension colors) {
    return Container(
      decoration: _boxDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: TableCalendar<void>(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
        focusedDay: _focusedDay,
        // Month-only view — the "format" toggle button is hidden by
        // restricting [availableCalendarFormats] to a single entry.
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: ''},
        // Only react to horizontal swipes (next/previous month). By default
        // the widget also eats vertical gestures for its format-toggle UX,
        // which swallows the outer ListView's scroll and makes the page feel
        // locked when the user drags over the calendar.
        availableGestures: AvailableGestures.horizontalSwipe,
        startingDayOfWeek: StartingDayOfWeek.saturday,
        selectedDayPredicate: (day) => isSameDay(day, _dueDate),
        onDaySelected: (selected, focused) {
          setState(() {
            _dueDate = DateTime(selected.year, selected.month, selected.day);
            _focusedDay = focused;
          });
        },
        onPageChanged: (f) => _focusedDay = f,
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ),
        // Force the month/year title to use Western digits even when the app
        // locale is Arabic. The package defaults to `DateFormat.yMMMM` which
        // renders "٢٠٢٦" under Arabic; we want "2026" across the whole app.
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, day) {
            return Center(
              child: Text(
                AppFuns.formatMonthYear(day),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            );
          },
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppColors.primaryMid,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryMid.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: AppColors.primaryMid,
          ),
          defaultTextStyle:
              TextStyle(fontFamily: 'Cairo', color: colors.textPrimary),
          weekendTextStyle:
              TextStyle(fontFamily: 'Cairo', color: colors.textSecondary),
          outsideTextStyle:
              TextStyle(fontFamily: 'Cairo', color: colors.textDisabled),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textMuted,
          ),
          weekendStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _progressSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: AppColors.primaryMid,
        thumbColor: AppColors.primaryMid,
        overlayColor: AppColors.primaryMid.withValues(alpha: 0.20),
      ),
      child: Slider(
        value: _progress.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        label: '$_progress%',
        onChanged: (v) => setState(() => _progress = v.round()),
      ),
    );
  }

  Widget _memberList(AppColorsExtension colors, ProjectTeamData team) {
    if (team.members.isEmpty) {
      return Text(
        'No project members'.tr(context),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: colors.textMuted,
        ),
      );
    }

    // Role labels attached to each member. Order matters (PM first, then
    // parent assignee) so the subtitle reads naturally.
    List<String> rolesFor(ProjectTeamMember m) {
      final labels = <String>[];
      if (m.id == team.managerId) {
        labels.add('Project manager'.tr(context));
      }
      // Only surface the parent-task-assignee role when we're creating a
      // subtask — meaningless in a root-task context.
      if (widget.mode == AddTaskMode.subtask &&
          widget.parentAssigneeId != null &&
          m.id == widget.parentAssigneeId) {
        labels.add('Parent task assignee'.tr(context));
      }
      return labels;
    }

    // Partition into 3 groups so the list always reads:
    //   1. Project manager
    //   2. Parent task assignee (subtask mode only)
    //   3. Everyone else (original server order preserved)
    // Dart's `sort` is not stable — partitioning gives us a deterministic
    // grouping without touching the server-provided order within a group.
    final pmFirst = <ProjectTeamMember>[];
    final parentFirst = <ProjectTeamMember>[];
    final others = <ProjectTeamMember>[];
    for (final m in team.members) {
      if (m.id == team.managerId) {
        pmFirst.add(m);
      } else if (widget.mode == AddTaskMode.subtask &&
          widget.parentAssigneeId != null &&
          m.id == widget.parentAssigneeId) {
        parentFirst.add(m);
      } else {
        others.add(m);
      }
    }
    final ordered = [...pmFirst, ...parentFirst, ...others];

    // The list lives inside a rounded card. A `Material` wrapper is required
    // for the CheckboxListTile's ripple/splash to actually paint — without
    // one, the Container's solid background masks the ink layer and tapping
    // looks dead.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: colors.bgCard,
        child: Column(
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  // Leave a little inset so the divider feels like a row
                  // separator, not a hard page break.
                  indent: 12,
                  endIndent: 12,
                  color: colors.gray300,
                ),
              _buildMemberTile(colors, ordered[i], rolesFor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(
    AppColorsExtension colors,
    ProjectTeamMember m,
    List<String> Function(ProjectTeamMember) rolesFor,
  ) {
    final roles = rolesFor(m);
    final selected = _memberIds.contains(m.id);
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => setState(() {
        if (v == true) {
          _memberIds.add(m.id);
        } else {
          _memberIds.remove(m.id);
        }
      }),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primaryMid,
      // Explicit splash/hover + tile color so the ripple is clearly visible
      // against the white card background. Without these, the default
      // colors blend into the card and the tap feels unresponsive.
      splashRadius: 24,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColors.primaryMid.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primaryMid.withValues(alpha: 0.06);
        }
        return null;
      }),
      dense: true,
      title: Row(
        children: [
          _Avatar(name: m.name, small: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      subtitle: roles.isEmpty
          ? null
          : Padding(
              // Aligns the subtitle with the end of the title (after the
              // avatar + spacer) so it doesn't sit awkwardly under the
              // circular avatar.
              padding: const EdgeInsetsDirectional.only(start: 32, top: 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final label in roles) _RoleTag(label: label),
                ],
              ),
            ),
    );
  }

  Widget _assigneeDropdown(
      AppColorsExtension colors, ProjectTeamData team) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(colors),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _assigneeId,
          hint: Text(
            'Pick an assignee'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
          items: [
            for (final m in team.members)
              DropdownMenuItem<int>(
                value: m.id,
                child: Row(
                  children: [
                    _Avatar(name: m.name, small: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (m.isManager)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PM',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _assigneeId = v),
        ),
      ),
    );
  }

  Widget _assigneeLocked(AppColorsExtension colors, ProjectTeamData team) {
    // Resolve the current user's display name. Order of preference:
    //   1. The matching entry in the project team (so we get the canonical
    //      name + any photo_url the server has).
    //   2. The auth profile itself (the user's own identity — guaranteed to
    //      be populated whenever this screen is reachable).
    // We deliberately never fall back to "—": if the user is logged in we
    // always have *some* name to show.
    final authEmp = ref.watch(authProvider).employee;
    final myId = authEmp?.id;

    ProjectTeamMember? teamMatch;
    if (myId != null) {
      for (final m in team.members) {
        if (m.id == myId) {
          teamMatch = m;
          break;
        }
      }
    }

    final displayName = teamMatch?.name ??
        authEmp?.name ??
        authEmp?.code ??
        '—';

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(colors).copyWith(
        color: colors.gray100.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          _Avatar(name: displayName, small: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          Icon(Icons.lock_outline_rounded,
              size: 16, color: colors.textMuted),
          const SizedBox(width: 4),
          Text(
            'Auto-assigned'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton(ProjectTeamData team) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMid,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        onPressed: _submitting ? null : () => _submit(team),
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : const Icon(Icons.check_circle_rounded),
        label: Text(
          _submitting
              ? 'Saving...'.tr(context)
              : 'Save task'.tr(context),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _ensureDefaultAssignee(ProjectTeamData team) {
    if (_assigneeId != null) return;
    final canPick = _effectiveCanPickAssignee(team);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final myId = _currentEmployeeId;
      if (canPick) {
        final ids = team.members.map((m) => m.id).toSet();
        if (myId != null && ids.contains(myId)) {
          setState(() => _assigneeId = myId);
          return;
        }
        final pm = team.managerId;
        if (pm != null && ids.contains(pm)) {
          setState(() => _assigneeId = pm);
          return;
        }
        if (team.members.isNotEmpty) {
          setState(() => _assigneeId = team.members.first.id);
        }
        return;
      }
      // Locked assignee — server forces creator; show self even if not in team list.
      if (myId != null) setState(() => _assigneeId = myId);
    });
  }

  /// Pre-select the first status (server-ordered, usually "TODO / للتنفيذ")
  /// the very first time the list resolves — so the dropdown never renders
  /// as an empty "Set status" placeholder.
  void _ensureDefaultStatus(List<TaskStatus> statuses) {
    if (_statusCode != null) return;
    if (statuses.isEmpty) return;
    final first = statuses.first.code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _statusCode = first);
    });
  }

  InputDecoration _inputDecoration({
    required AppColorsExtension colors,
    required String hint,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.gray100),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(fontFamily: 'Cairo', color: colors.textMuted, fontSize: 13),
      filled: true,
      fillColor: colors.bgCard,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primaryMid, width: 1.4),
      ),
    );
  }

  BoxDecoration _boxDecoration(AppColorsExtension colors) {
    return BoxDecoration(
      color: colors.bgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.gray100),
      boxShadow: AppShadows.card,
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String titleKey;
  final String subtitle;
  final VoidCallback onBack;

  const _Header({
    required this.titleKey,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 14,
        right: 14,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleKey.tr(context),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.subdirectory_arrow_right_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches the error text rendered by `TextFormField` under invalid input,
/// but for non-TextFormField sections (dropdowns, calendar, slider, members).
/// Uses the same typography so the error reads consistently across fields.
class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 14, color: AppColors.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: AppColors.error,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _SectionLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colors.textSecondary,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small pill shown under a member's name listing a role that applies to
/// them in the current context (e.g. "Project manager", "Parent task
/// assignee"). Purely informative — does not change selection behavior.
class _RoleTag extends StatelessWidget {
  final String label;
  const _RoleTag({required this.label});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7C3AED); // purple — reads as "status"
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool small;
  const _Avatar({required this.name, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 22.0 : 28.0;
    final initials =
        name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryMid.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryMid,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry'.tr(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}
