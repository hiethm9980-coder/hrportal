import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/errors/exceptions.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';

import '../../data/models/ai_bulk_subtasks_models.dart';
import '../widgets/task_progress_palette.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// AI-assisted bulk subtasks form.
///
/// User types up to 10 short titles separated by `;` and the backend
/// expands each into a real subtask (title + description + sane
/// defaults). On success we pop with `true` so the caller can refresh
/// the subtasks list.
///
/// Rate limit: 5 req/min/user. On 429 the screen drives a local
/// countdown using `details.retry_after_seconds` and re-enables the
/// submit button when it ticks down to 0.
class AiCreateSubtasksScreen extends ConsumerStatefulWidget {
  final int parentTaskId;
  final String parentTaskTitle;

  const AiCreateSubtasksScreen({
    super.key,
    required this.parentTaskId,
    required this.parentTaskTitle,
  });

  @override
  ConsumerState<AiCreateSubtasksScreen> createState() =>
      _AiCreateSubtasksScreenState();
}

class _AiCreateSubtasksScreenState
    extends ConsumerState<AiCreateSubtasksScreen> {
  static const int _maxTasks = 10;
  // Capped well below the server's 4000-char ceiling so a single batch
  // doesn't burn through a disproportionate chunk of the AI provider's
  // token budget — 10 short titles fit comfortably in 500 chars.
  static const int _maxChars = 500;

  final _controller = TextEditingController();
  /// FocusNode للحقل — مرّر للـ [_TextInput] ويُستخدم في [_insertSemicolon]
  /// لإعادة التركيز للحقل على الويب فقط بعد الضغط على زر "إضافة ;".
  final _textFocus = FocusNode();
  bool _isSubmitting = false;

  /// Active rate-limit cooldown in seconds. Zero means «no cooldown».
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // ── Smart defaults (sent only when user touches them) ─────────────
  /// 0..100 progress applied to every generated subtask. The server
  /// derives status from this value (100→DONE, 0→TODO, else IN_PROGRESS).
  int _progress = 0;

  /// Inclusive day-only date. `null` means «use server default» (tomorrow).
  DateTime? _dueDateStart;

  /// Sequential = +1 day per task; Fixed = same date for everyone.
  AiBulkDueDateMode _dueDateMode = AiBulkDueDateMode.sequential;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _textFocus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Live cleanup rules applied during typing AND on the «Insert ;»
  /// button:
  ///
  ///   - leading whitespace + `;` → stripped
  ///   - `;;` (with any whitespace between) → collapsed to a single `; `
  ///
  /// Trailing `;` is intentionally kept while the user is in the field —
  /// stripping it would erase the separator they just typed before the
  /// next task name. The trailing-`;` trim only runs in [_cleanForApi]
  /// right before submit.
  static final RegExp _liveLeading = RegExp(r'^[\s;]+');
  static final RegExp _liveConsecutive = RegExp(r'(?:;\s*){2,}');

  /// Pure helper — produces the normalized version of [raw]. Identical
  /// rules are applied by the [_onTextChanged] listener (after every IME
  /// commit) and by [_insertSemicolon] (so tapping the «+» button never
  /// produces a leading or duplicate `;` either).
  ///
  /// قواعد التنظيف الحيّ:
  /// 1) أي سطر جديد (`\n` / `\r` / `\r\n`) → مسافة واحدة.
  /// 2) تقليص أي تتابع مسافات (سواء كانت ASCII space أو tab أو NBSP) إلى
  ///    مسافة واحدة فقط.
  /// 3) ممنوع البدء بمسافة أو فاصلة منقوطة (`;`).
  /// 4) تقليص أي `;;` (مع/بدون مسافات بينها) إلى `; ` واحد.
  static String _normalizeLive(String raw) {
    return raw
        // 1) line breaks → مسافة واحدة.
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        // 2) أي تتابع مسافات → مسافة واحدة (يشمل tab, NBSP, …).
        //    `\s` يطابق line breaks أيضاً لكنها أُزيلت في الخطوة 1.
        .replaceAll(RegExp(r'[ \t ]{2,}'), ' ')
        // 3) منع البدء بمسافة أو ;.
        .replaceFirst(_liveLeading, '')
        // 4) تقليص ;; إلى ; مع مسافة واحدة.
        .replaceAll(_liveConsecutive, '; ');
  }

  /// Listener-based normalization. Runs AFTER every commit from the IME
  /// (including Arabic composing keyboards, voice input, paste, …) where
  /// a [TextInputFormatter] would be silently overridden by the IME's
  /// own composing buffer.
  ///
  /// Recursion is naturally bounded: rewriting the controller value
  /// fires another listener call, but the second pass produces an
  /// identical string so the early-return short-circuits.
  void _onTextChanged() {
    final original = _controller.text;
    final cleaned = _normalizeLive(original);

    if (cleaned != original) {
      // Preserve distance from the end so the caret tracks the user's
      // typing position when leading / duplicate `;` are stripped.
      final tail = original.length - _controller.selection.end;
      final newOffset = (cleaned.length - tail).clamp(0, cleaned.length);
      _controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: newOffset),
        composing: TextRange.empty,
      );
      // The setter above will re-fire this listener; the second pass
      // matches `cleaned == original` and falls through to setState.
      return;
    }

    setState(() {});
  }

  /// Final cleanup applied right before sending to the server. Mirrors
  /// the live [_SemicolonNormalizer] *plus* strips trailing `;` (we
  /// can't do that during typing — it'd erase the separator the user
  /// just typed before adding the next task).
  String _cleanForApi(String raw) {
    return raw
        // Strip any leading whitespace + semicolons.
        .replaceFirst(RegExp(r'^[\s;]+'), '')
        // Collapse consecutive `;` (optionally separated by whitespace)
        // into a single `; ` separator.
        .replaceAll(RegExp(r'(?:;\s*){2,}'), '; ')
        // Strip any trailing whitespace + semicolons.
        .replaceFirst(RegExp(r'[\s;]+$'), '')
        .trim();
  }

  /// Number of non-empty, `;`-separated entries currently in the field.
  int get _taskCount {
    return _controller.text
        .split(RegExp(r';+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .length;
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _cooldownSeconds == 0 &&
      _controller.text.trim().isNotEmpty &&
      _taskCount <= _maxTasks;

  /// Insert `; ` at the caret so the user doesn't have to switch keyboards
  /// just to grab a semicolon (especially on Arabic layouts).
  ///
  /// Runs the same [_normalizeLive] pass as the typing listener, so
  /// tapping the button:
  ///   - on an empty field → does nothing (would otherwise leave a
  ///     leading `;`),
  ///   - right after an existing `;` → collapses to one separator
  ///     instead of producing `;;`.
  void _insertSemicolon() {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;

    // Insert raw `; ` first, then normalize. This handles all the edge
    // cases (empty field, neighbouring `;`, surrounding whitespace) in
    // a single pass and keeps the rules in one place.
    final raw = value.text.replaceRange(start, end, '; ');
    final cleaned = _normalizeLive(raw);

    // Where should the caret land? «end of inserted separator» — i.e.
    // distance-from-end equal to whatever was after the original
    // selection. After cleanup that translates into the same tail
    // distance, clamped to the final string length.
    final tail = raw.length - (start + 2);
    final newOffset = (cleaned.length - tail).clamp(0, cleaned.length);

    _controller.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );

    // ✅ ويب فقط: أعِد التركيز للحقل ليكمل المستخدم الكتابة فوراً بدون
    // الحاجة للضغط على المربع. على الموبايل لا نفعل ذلك لتجنّب فتح
    // لوحة المفاتيح بشكل غير متوقع بعد ضغطة زر.
    if (kIsWeb) {
      _textFocus.requestFocus();
    }
  }

  /// Open a Material date picker. Allow «today» so the user can mark
  /// already-completed work as `default_progress: 100`. The server still
  /// accepts past dates — see «archive old work» in the API doc.
  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _dueDateStart ?? today.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 1),
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueDateStart = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        t.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  /// Read cooldown seconds from a [RateLimitedException]. The contract puts
  /// the canonical value in `details.retry_after_seconds`; we fall back to
  /// `details.rate_limit.reset_in_seconds` defensively.
  int? _retryAfterFrom(RateLimitedException e) {
    final d = e.details;
    if (d == null) return null;
    final v = d['retry_after_seconds'];
    if (v is num) return v.toInt();
    final rl = d['rate_limit'];
    if (rl is Map) {
      final r = rl['reset_in_seconds'];
      if (r is num) return r.toInt();
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    // Drop the IME before the network call so the loading overlay isn't
    // partially hidden behind the keyboard, and the SnackBar that fires
    // on success/failure has the full screen width to land on.
    AppFuns.hideKeyboard();

    final auth = ref.read(authProvider);
    final jobTitle = (auth.employee?.jobTitle ?? '').trim();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      final result = await repo.createSubtasksWithAi(
        widget.parentTaskId,
        AiBulkSubtasksRequest(
          // Server requires a non-empty job title — fall back to a generic
          // label so the UI still works for employees without one set.
          employeeJob: jobTitle.isEmpty ? 'موظف' : jobTitle,
          parentTask: widget.parentTaskTitle,
          // Apply the same cleanup the server runs (strip leading /
          // trailing `;`, collapse internal duplicates) so the user
          // sees the count match what the server will create.
          taskText: _cleanForApi(_controller.text),
          // Always send the user's chosen progress so the preview matches
          // reality — backend treats 0 as TODO which is also our default.
          defaultProgress: _progress,
          dueDateStart: _dueDateStart != null
              ? AppFuns.toUtcDateOnlyYmdForApi(_dueDateStart!)
              : null,
          dueDateMode: _dueDateMode,
        ),
      );
      if (!mounted) return;

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Text(
            '${'Created %d subtasks'.tr(context).replaceAll('%d', '${result.createdCount}')}'
            ' · '
            '${'%d attempts left'.tr(context).replaceAll('%d', '${result.rateLimitRemaining}')}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on RateLimitedException catch (e) {
      if (!mounted) return;
      final retry = _retryAfterFrom(e);
      if (retry != null && retry > 0) _startCooldown(retry);
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    } on ApiException catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overLimit = _taskCount > _maxTasks;

    return PopScope(
      // Don't let the user back out mid-submit — the request is in flight
      // and popping would leak the result + still mutate the parent.
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Create with AI'.tr(context),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ParentBanner(parentTitle: widget.parentTaskTitle),
                            const SizedBox(height: 14),
                            _HelpBanner(maxTasks: _maxTasks),
                            const SizedBox(height: 12),
                            // Fixed-height text area so the form stays
                            // scrollable when the defaults card pushes
                            // down — Expanded inside a scroll view crashes.
                            SizedBox(
                              height: 180,
                              child: _TextInput(
                                controller: _controller,
                                focusNode: _textFocus,
                                maxChars: _maxChars,
                                enabled: !_isSubmitting,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${'Tasks'.tr(context)}: $_taskCount / $_maxTasks',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: overLimit
                                        ? AppColors.error
                                        : colors.textPrimary,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : _insertSemicolon,
                                  style: OutlinedButton.styleFrom(
                                    // Light → navy primary text. Dark →
                                    // white from the theme default; we
                                    // skip overriding the foreground so
                                    // the theme wins instead of fighting
                                    // it with a fixed dark-on-dark hue.
                                    foregroundColor: context.isDark
                                        ? null
                                        : AppColors.primaryMid,
                                    side: BorderSide(
                                      color: context.isDark
                                          ? AppColors.primaryMid
                                              .withValues(alpha: 0.55)
                                          : AppColors.primaryBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    'Insert ;'.tr(context),
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _DefaultsCard(
                              progress: _progress,
                              onProgressChanged: (v) =>
                                  setState(() => _progress = v),
                              dueDate: _dueDateStart,
                              onPickDueDate: _pickDueDate,
                              onClearDueDate: () =>
                                  setState(() => _dueDateStart = null),
                              mode: _dueDateMode,
                              onModeChanged: (m) =>
                                  setState(() => _dueDateMode = m),
                              taskCount: _taskCount,
                              enabled: !_isSubmitting,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_cooldownSeconds > 0) ...[
                      const SizedBox(height: 12),
                      _CooldownBanner(seconds: _cooldownSeconds),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryMid,
                          disabledBackgroundColor:
                              AppColors.primaryMid.withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _canSubmit ? _submit : null,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          'Generate subtasks'.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSubmitting)
                const Positioned.fill(child: _SubmittingOverlay()),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Pieces
// ═══════════════════════════════════════════════════════════════════

class _ParentBanner extends StatelessWidget {
  final String parentTitle;
  const _ParentBanner({required this.parentTitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Dark-mode adaptation: the light-mode `primarySoft` fill is nearly
    // white and renders the (already light) text invisible against it.
    // We tint with `primaryMid` at low alpha so the banner still reads
    // as a primary-accented panel against the dark background.
    final isDark = context.isDark;
    final fill = isDark
        ? AppColors.primaryMid.withValues(alpha: 0.16)
        : AppColors.primarySoft;
    final border = isDark
        ? AppColors.primaryMid.withValues(alpha: 0.40)
        : AppColors.primaryBorder;
    final iconColor =
        isDark ? AppColors.primaryLight : AppColors.primaryMid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_rounded,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent task'.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parentTitle,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpBanner extends StatelessWidget {
  final int maxTasks;
  const _HelpBanner({required this.maxTasks});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Theme-aware gold tint: light mode keeps the cream-paper feel; dark
    // mode swaps to a muted gold-on-dark so the icon stays readable
    // without bleaching out the rest of the page.
    final isDark = context.isDark;
    final fill = isDark
        ? AppColors.gold.withValues(alpha: 0.16)
        : AppColors.goldSoft;
    final border = isDark
        ? AppColors.gold.withValues(alpha: 0.45)
        : AppColors.goldLight.withValues(alpha: 0.4);
    final iconColor = isDark ? AppColors.goldLight : AppColors.goldDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI subtasks help'
                  .tr(context)
                  .replaceAll('%d', '$maxTasks'),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxChars;
  final bool enabled;

  const _TextInput({
    required this.controller,
    required this.focusNode,
    required this.maxChars,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.inputBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        maxLength: maxChars,
        // ملاحظة: نتعمّد `TextInputType.text` (وليس multiline) لمنع زر
        // Enter من الظهور على لوحة المفاتيح. النص سيبقى يتلفّ تلقائياً
        // داخل المربع بفضل `maxLines: null` و `expands: true`.
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxChars),
          // Live cleanup: forbid leading `;` and collapse consecutive
          // `;;`. Also strips any line breaks (the user can't type them
          // anymore, but this guards against paste).
          _SemicolonNormalizer(),
        ],
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          height: 1.5,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintText: 'AI subtasks placeholder'.tr(context),
          hintStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13.5,
            height: 1.5,
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CooldownBanner extends StatelessWidget {
  final int seconds;
  const _CooldownBanner({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final fill = isDark
        ? AppColors.warning.withValues(alpha: 0.18)
        : AppColors.warningSoft;
    final border = AppColors.warning.withValues(alpha: 0.45);
    // Dark mode needs a lighter warning hue so the text stays legible
    // on the deeper amber-tinted fill.
    final textColor =
        isDark ? AppColors.warningSoft : AppColors.warningDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: textColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Try again in %s seconds'
                  .tr(context)
                  .replaceAll('%s', '$seconds'),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Smart-defaults card: progress slider + due date + spread mode + live
// preview. All three values are forwarded to the AI bulk endpoint and
// applied to every generated subtask.
// ───────────────────────────────────────────────────────────────────

class _DefaultsCard extends StatelessWidget {
  final int progress;
  final ValueChanged<int> onProgressChanged;
  final DateTime? dueDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onClearDueDate;
  final AiBulkDueDateMode mode;
  final ValueChanged<AiBulkDueDateMode> onModeChanged;
  final int taskCount;
  final bool enabled;

  const _DefaultsCard({
    required this.progress,
    required this.onProgressChanged,
    required this.dueDate,
    required this.onPickDueDate,
    required this.onClearDueDate,
    required this.mode,
    required this.onModeChanged,
    required this.taskCount,
    required this.enabled,
  });

  /// Status mirroring the server's full 4-tier auto-derive rule:
  ///
  /// ```
  ///   0       → TODO         (red)
  ///   1..69   → IN_PROGRESS  (orange)
  ///   70..99  → REVIEW       (blue)   ← was previously folded into IN_PROGRESS
  ///   100     → DONE         (green)
  /// ```
  ///
  /// Color is sourced from [TaskProgressPalette.forPercent] so the
  /// preview chip and the slider track always agree.
  ({String label, Color color, IconData icon}) get _statusPreview {
    final color = TaskProgressPalette.forPercent(progress);
    if (progress >= 100) {
      return (
        label: 'Status: Completed',
        color: color,
        icon: Icons.check_circle_rounded,
      );
    }
    if (progress >= 70) {
      return (
        label: 'Status: Review',
        color: color,
        icon: Icons.fact_check_outlined,
      );
    }
    if (progress >= 1) {
      return (
        label: 'Status: In progress',
        color: color,
        icon: Icons.timelapse_rounded,
      );
    }
    return (
      label: 'Status: To do',
      color: color,
      icon: Icons.radio_button_unchecked_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final preview = _statusPreview;
    // Display dates use the project's [AppFuns.formatDate] helper so the
    // user sees a localized day-name + month-name (e.g. "الأحد، 10 مايو
    // 2026") with **English digits** — matches the rest of the app and
    // satisfies the Arabic-numerals → ASCII rule.
    final effectiveStart = dueDate ??
        DateTime.now().add(const Duration(days: 1));
    final dayOnly = DateTime(
      effectiveStart.year,
      effectiveStart.month,
      effectiveStart.day,
    );
    final effectiveStartLabel = AppFuns.formatDate(dayOnly);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section title ──────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppColors.primaryMid,
              ),
              const SizedBox(width: 8),
              Text(
                'Smart defaults'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Smart defaults help'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              height: 1.45,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // ── Progress slider ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Default progress'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: preview.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$progress%',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: preview.color,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: preview.color,
              inactiveTrackColor: preview.color.withValues(alpha: 0.18),
              thumbColor: preview.color,
              overlayColor: preview.color.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: progress.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$progress%',
              onChanged:
                  enabled ? (v) => onProgressChanged(v.round()) : null,
            ),
          ),
          // Status preview chip
          Row(
            children: [
              Icon(preview.icon, size: 16, color: preview.color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  preview.label.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: preview.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 14),

          // ── Due date row ────────────────────────────────────────
          Text(
            'Start due date'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? onPickDueDate : null,
                  style: OutlinedButton.styleFrom(
                    // Light → navy primary. Dark → fall back to the
                    // theme's white default (passing null skips this
                    // entry on the resulting ButtonStyle).
                    foregroundColor: context.isDark
                        ? null
                        : AppColors.primaryMid,
                    side: BorderSide(color: colors.inputBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    dueDate != null
                        ? AppFuns.formatDate(dueDate!)
                        : '${'Tomorrow (default)'.tr(context)}'
                            ' · $effectiveStartLabel',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (dueDate != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Reset'.tr(context),
                  onPressed: enabled ? onClearDueDate : null,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // ── Mode segmented buttons ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Sequential'.tr(context),
                  hint: 'Sequential hint'.tr(context),
                  icon: Icons.linear_scale_rounded,
                  selected: mode == AiBulkDueDateMode.sequential,
                  onTap: enabled
                      ? () => onModeChanged(AiBulkDueDateMode.sequential)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Fixed'.tr(context),
                  hint: 'Fixed hint'.tr(context),
                  icon: Icons.event_repeat_rounded,
                  selected: mode == AiBulkDueDateMode.fixed,
                  onTap: enabled
                      ? () => onModeChanged(AiBulkDueDateMode.fixed)
                      : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 12),

          // ── Live preview ────────────────────────────────────────
          _PreviewBlock(
            statusLabel: preview.label,
            statusColor: preview.color,
            statusIcon: preview.icon,
            startLabel: effectiveStartLabel,
            mode: mode,
            taskCount: taskCount,
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = context.isDark;
    // The «selected» state needs a primary-tinted fill that works on
    // both themes — pure `primarySoft` is invisible against the dark
    // bg, and a flat tint on light mode looks unfinished.
    final bg = selected
        ? (isDark
            ? AppColors.primaryMid.withValues(alpha: 0.22)
            : AppColors.primarySoft)
        : colors.bgSection;
    final border = selected
        ? (isDark
            ? AppColors.primaryMid.withValues(alpha: 0.55)
            : AppColors.primaryBorder)
        : colors.inputBorder;
    final fg = selected
        ? (isDark ? AppColors.primaryLight : AppColors.primary)
        : colors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                height: 1.35,
                color: colors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String startLabel;
  final AiBulkDueDateMode mode;
  final int taskCount;

  const _PreviewBlock({
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.startLabel,
    required this.mode,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateLine = mode == AiBulkDueDateMode.fixed
        ? 'Preview fixed dates'.tr(context).replaceAll('%s', startLabel)
        : 'Preview sequential dates'
            .tr(context)
            .replaceAll('%s', startLabel);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.bgSection,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Preview'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  statusLabel.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.event_rounded,
                  size: 14, color: colors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  dateLine,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (taskCount > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.format_list_numbered_rounded,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${'Tasks'.tr(context)}: $taskCount',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmittingOverlay extends StatelessWidget {
  const _SubmittingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Generating subtasks...'.tr(context),
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Live `;` normalizer.
// ═══════════════════════════════════════════════════════════════════
//
// Runs on every keystroke. It enforces two rules at the input level:
//
//  1. The text must NOT start with `;` (any leading whitespace + `;`
//     are stripped silently).
//  2. Consecutive `;` (with optional whitespace between them) are
//     collapsed to a single `; ` separator.
//
// We deliberately do NOT strip a trailing `;` during typing — the user
// types it on purpose to start the next task. The final trailing-`;`
// trim is applied once, in [_cleanForApi], right before submit.
//
// Cursor handling: when text shrinks we preserve the user's distance
// from the *end* of the new text. That feels right for the dominant
// pattern (typing at the end) and keeps the caret near where it just
// was when an edit lands mid-string.

class _SemicolonNormalizer extends TextInputFormatter {
  static final RegExp _leading = RegExp(r'^[\s;]+');
  static final RegExp _consecutive = RegExp(r'(?:;\s*){2,}');
  static final RegExp _newlines = RegExp(r'[\r\n]+');
  static final RegExp _multiSpaces = RegExp(r'[ \t ]{2,}');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final original = newValue.text;
    var cleaned = original
        // 1) أي سطر جديد → مسافة.
        .replaceAll(_newlines, ' ')
        // 2) مسافات متعددة → مسافة واحدة.
        .replaceAll(_multiSpaces, ' ')
        // 3) ممنوع البدء بمسافة أو ;.
        .replaceFirst(_leading, '')
        // 4) ;; → ;
        .replaceAll(_consecutive, '; ');

    if (cleaned == original) return newValue;

    // Preserve distance from end so the caret tracks the user's typing
    // position when leading/duplicate `;` are stripped.
    final tail = original.length - newValue.selection.end;
    final newOffset = (cleaned.length - tail).clamp(0, cleaned.length);

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }
}
