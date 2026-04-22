import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/features/auth/presentation/providers/auth_providers.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../../data/models/comment_models.dart';
import '../../../providers/comments_provider.dart';
import '../../../providers/mention_candidates_provider.dart';

/// "Comments" tab of the task detail screen.
///
/// Layout — WhatsApp inspired:
///   ┌─────────────────────────────────┐
///   │ Header (back · title · search)  │  ← gradient bar
///   ├─────────────────────────────────┤
///   │   ─── Saturday, Feb 2 2026 ─── │  ← date divider
///   │  ┌──────────────┐               │
///   │  │ Their bubble │               │  ← left, neutral
///   │  └──────────────┘               │
///   │             ┌──────────────┐    │
///   │             │  My bubble   │    │  ← right, primary
///   │             └──────────────┘    │
///   │                                 │
///   │  [Mention popup overlays here]  │  ← when @ is being typed
///   ├─────────────────────────────────┤
///   │ TextField                  send │  ← composer (sticky bottom)
///   └─────────────────────────────────┘
///
/// "Mine" vs "theirs" is decided by [Comment.canDelete] — the backend
/// already enforces that only the author can delete, which gives us a free
/// owner flag without needing to pull the current user's id.
class CommentsTab extends ConsumerStatefulWidget {
  final int taskId;
  final String? initialTitle;

  const CommentsTab({
    super.key,
    required this.taskId,
    this.initialTitle,
  });

  @override
  ConsumerState<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<CommentsTab> {
  // ── Header search ─────────────────────────────────────────────────
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;

  // ── Composer ──────────────────────────────────────────────────────
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _listScroll = ScrollController();

  // Mention popup state. We track the position of the active `@` so we can
  // splice the picked candidate token back into the text without disturbing
  // anything the user typed before/after the trigger.
  bool _showMentionPopup = false;
  int? _mentionStart; // index of the @ in _composerController.text
  Timer? _mentionDebounce;

  @override
  void initState() {
    super.initState();
    _composerController.addListener(_onComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commentsProvider(widget.taskId).notifier).load();
    });
  }

  @override
  void dispose() {
    _composerController.removeListener(_onComposerChanged);
    _composerController.dispose();
    _composerFocus.dispose();
    _searchController.dispose();
    _listScroll.dispose();
    _searchDebounce?.cancel();
    _mentionDebounce?.cancel();
    super.dispose();
  }

  // ── Search handlers ───────────────────────────────────────────────

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      ref.read(commentsProvider(widget.taskId).notifier).setSearch(v);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(commentsProvider(widget.taskId).notifier).setSearch('');
  }

  void _toggleSearch() => setState(() => _showSearch = !_showSearch);

  Future<void> _refresh() async {
    _searchController.clear();
    final n = ref.read(commentsProvider(widget.taskId).notifier)
      ..setSearch('');
    await n.load();
    _scrollToBottom(immediate: true);
  }

  // ── Mention detection ─────────────────────────────────────────────

  /// Re-runs on every text/selection change. Looks at the substring before
  /// the cursor for an unclosed `@xyz` token. If found, opens the popup with
  /// `xyz` as the query; otherwise closes it.
  void _onComposerChanged() {
    final text = _composerController.text;
    final selection = _composerController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _hideMentionPopup();
      return;
    }
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _hideMentionPopup();
      return;
    }

    // Find the most recent `@` before the cursor that:
    //   a) is at the start OR preceded by whitespace
    //   b) has no whitespace between it and the cursor
    int? atIndex;
    for (int i = cursor - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == '@') {
        final isStart = i == 0;
        final prev = isStart ? '' : text[i - 1];
        if (isStart || _isWhitespace(prev)) {
          atIndex = i;
        }
        break;
      }
      if (_isWhitespace(ch) || ch == '\n') break;
    }

    if (atIndex == null) {
      _hideMentionPopup();
      return;
    }

    final query = text.substring(atIndex + 1, cursor);
    setState(() {
      _showMentionPopup = true;
      _mentionStart = atIndex;
    });

    // Debounce the network query a bit so we don't fire on every keystroke.
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref
          .read(mentionCandidatesProvider(widget.taskId).notifier)
          .setQuery(query);
    });
  }

  void _hideMentionPopup() {
    if (!_showMentionPopup) return;
    _mentionDebounce?.cancel();
    setState(() {
      _showMentionPopup = false;
      _mentionStart = null;
    });
  }

  /// Replace the active `@xyz` segment with the chosen candidate's
  /// pre-rendered token, then close the popup and put the cursor right after
  /// the inserted token (with a trailing space so the user can keep typing).
  void _onMentionPick(MentionCandidate c) {
    final start = _mentionStart;
    if (start == null) return;
    final text = _composerController.text;
    final cursor = _composerController.selection.baseOffset;
    final before = text.substring(0, start);
    final after = cursor > text.length ? '' : text.substring(cursor);
    final inserted = '${c.mentionToken} ';
    final newText = '$before$inserted$after';
    final newCursor = (before + inserted).length;
    _composerController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _hideMentionPopup();
  }

  // ── Sending ───────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    _hideMentionPopup();
    try {
      await ref.read(commentsProvider(widget.taskId).notifier).send(text);
      _composerController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    // The list is in chronological order with newest at the END, so scroll
    // to the maxScrollExtent. Wait one frame so the freshly-appended message
    // is laid out before we animate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listScroll.hasClients) return;
      final target = _listScroll.position.maxScrollExtent;
      if (immediate) {
        _listScroll.jumpTo(target);
      } else {
        _listScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Delete ────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Comment c) async {
    // Styled to match the Attachments tab's delete confirmation exactly —
    // same AlertDialog shape, same Cairo typography, same destructive-as-
    // red TextButton (no filled button). Keeps the two destructive flows
    // feeling like siblings instead of cousins.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete comment'.tr(ctx),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          'Are you sure you want to delete this comment?'.tr(ctx),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'.tr(ctx),
                style: const TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete'.tr(ctx),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final successText = 'Comment deleted'.tr(context);
    try {
      await ref.read(commentsProvider(widget.taskId).notifier).delete(c.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(successText, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsProvider(widget.taskId));
    // Newest-at-bottom needs chronological order — server gives us DESC.
    final ordered = state.comments.reversed.toList();
    final items = _groupByDate(ordered, context);

    // After a fresh load, jump to bottom so the user sees the newest msgs.
    // (Subsequent appends via _send() also call _scrollToBottom themselves.)
    ref.listen(commentsProvider(widget.taskId).select((s) => s.comments.length),
        (prev, next) {
      if (prev == null || next > (prev)) _scrollToBottom(immediate: prev == null);
    });

    return Column(
      children: [
        _CommentsHeader(
          parentTitle: widget.initialTitle ?? '',
          count: state.summary.count,
          searchActive: state.filter.q.trim().isNotEmpty,
          showSearch: _showSearch,
          searchController: _searchController,
          onBack: () => Navigator.of(context).maybePop(),
          onToggleSearch: _toggleSearch,
          onClearSearch: _clearSearch,
          onSearchChanged: _onSearchChanged,
          onRefresh: _refresh,
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _MessagesArea(
                      state: state,
                      items: items,
                      scrollController: _listScroll,
                      // Needed by each bubble to decide "mine" vs "theirs"
                      // now that `canDelete` is no longer a proxy for
                      // authorship (PMs can delete any comment).
                      currentEmployeeId:
                          ref.watch(authProvider).employee?.id,
                      onDelete: _confirmDelete,
                      onRetry: () => ref
                          .read(commentsProvider(widget.taskId).notifier)
                          .load(),
                    ),
                    if (_showMentionPopup)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _MentionPopup(
                          taskId: widget.taskId,
                          onPick: _onMentionPick,
                          onClose: _hideMentionPopup,
                        ),
                      ),
                    if (state.isMutating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.summary.canAdd)
                _Composer(
                  controller: _composerController,
                  focusNode: _composerFocus,
                  isSending: state.isSending || state.isMutating,
                  onSend: _send,
                )
              else
                const _ReadOnlyBanner(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header — back · title · search · refresh.
// Mirrors the look of the time-logs / subtasks tabs.
// ═══════════════════════════════════════════════════════════════════

class _CommentsHeader extends StatelessWidget {
  final String parentTitle;
  final int count;
  final bool searchActive;
  final bool showSearch;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  const _CommentsHeader({
    required this.parentTitle,
    required this.count,
    required this.searchActive,
    required this.showSearch,
    required this.searchController,
    required this.onBack,
    required this.onToggleSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 14,
        right: 14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Comments'.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (parentTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          parentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _IconBtn(
                icon: showSearch
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.search_rounded,
                active: !showSearch && searchActive,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: showSearch
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _SearchField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      onClear: onClearSearch,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Messages area — WhatsApp-style ListView with date dividers.
// The list is sized to fill the available space; the input bar (or read-
// only banner) sits below in the parent Column.
// ═══════════════════════════════════════════════════════════════════

class _MessagesArea extends StatelessWidget {
  final CommentsState state;
  final List<_ChatItem> items;
  final ScrollController scrollController;
  final int? currentEmployeeId;
  final void Function(Comment) onDelete;
  final Future<void> Function() onRetry;

  const _MessagesArea({
    required this.state,
    required this.items,
    required this.scrollController,
    required this.currentEmployeeId,
    required this.onDelete,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (state.isLoading && state.comments.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.error != null && state.comments.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }
    if (state.comments.isEmpty) {
      return _EmptyView(
        hasFilter: state.filter.q.isNotEmpty,
        canAdd: state.summary.canAdd,
      );
    }

    return Container(
      color: colors.bg,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          if (item is _DateDividerItem) {
            return _DateDivider(label: item.label);
          }
          if (item is _MessageItem) {
            return _MessageBubble(
              comment: item.comment,
              onDelete: () => onDelete(item.comment),
              currentEmployeeId: currentEmployeeId,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Date divider — centered pill: "اليوم" / "أمس" / "السبت، 2 فبراير 2026".
// ═══════════════════════════════════════════════════════════════════

class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: colors.gray100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Message bubble — WhatsApp-like. Mine = primary on the trailing edge,
// theirs = neutral on the leading edge (so RTL flips automatically).
// ═══════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final Comment comment;
  final VoidCallback onDelete;

  /// Employee id of the currently-logged-in user. Used purely to decide
  /// whether this bubble is "mine" (right-aligned, blue) or theirs.
  ///
  /// We used to derive `isMine` from `comment.canDelete` — that was fine
  /// when the backend only let the author delete. After the policy change
  /// that lets project managers also delete any comment, `canDelete` no
  /// longer implies authorship, so bubble placement needs a different
  /// source of truth: the author id.
  final int? currentEmployeeId;

  const _MessageBubble({
    required this.comment,
    required this.onDelete,
    required this.currentEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final authorId = comment.author?.id;
    final isMine = currentEmployeeId != null &&
        authorId != null &&
        authorId == currentEmployeeId;
    final bgColor =
        isMine ? AppColors.primaryMid.withOpacity(0.92) : colors.bgCard;
    final fgColor = isMine ? Colors.white : colors.textPrimary;
    final timeColor = isMine
        ? Colors.white.withOpacity(0.75)
        : colors.textSecondary;
    final authorColor = isMine
        ? Colors.white.withOpacity(0.85)
        : AppColors.primaryMid;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMine ? 14 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 14),
        ),
        border: isMine ? null : Border.all(color: colors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author name + role badge (for theirs) — skip on own bubbles,
          // like WhatsApp 1-to-1 chats where you don't see your own name.
          if (!isMine && comment.author != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      comment.author!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: authorColor,
                      ),
                    ),
                  ),
                  if (comment.authorRole != null) ...[
                    const SizedBox(width: 6),
                    _RoleBadge(role: comment.authorRole!),
                  ],
                ],
              ),
            ),
          _RichBody(
            body: comment.body,
            color: fgColor,
            isMine: isMine,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (comment.isEdited)
                Padding(
                  padding: const EdgeInsets.only(right: 6, left: 6),
                  child: Text(
                    'edited'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: timeColor,
                    ),
                  ),
                ),
              Text(
                _formatTime(comment.createdAt),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: timeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        // alignment switches sides automatically in RTL because we use
        // start/end (logical) instead of left/right.
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Long-press to delete — gated by `canDelete` from the server,
          // which is now computed as (author || project manager). That's
          // broader than "isMine", so PMs can long-press any bubble to
          // delete it while regular members only get the affordance on
          // their own messages.
          if (comment.canDelete)
            GestureDetector(
              onLongPress: onDelete,
              child: bubble,
            )
          else
            bubble,
        ],
      ),
    );
  }
}

/// Renders a comment body, replacing every `@[emp:ID|NAME]` token with a
/// pill-styled mention chip inside a RichText.
class _RichBody extends StatelessWidget {
  final String body;
  final Color color;
  final bool isMine;

  const _RichBody({
    required this.body,
    required this.color,
    required this.isMine,
  });

  static final _mentionRegex = RegExp(r'@\[emp:(\d+)\|([^\]]+)\]');

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in _mentionRegex.allMatches(body)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: body.substring(lastEnd, m.start)));
      }
      final name = m.group(2) ?? '';
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _MentionInlineChip(name: name, isMine: isMine),
      ));
      lastEnd = m.end;
    }
    if (lastEnd < body.length) {
      spans.add(TextSpan(text: body.substring(lastEnd)));
    }
    if (spans.isEmpty) {
      // Plain text fast-path.
      return Text(
        body,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: color,
          height: 1.4,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: color,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}

class _MentionInlineChip extends StatelessWidget {
  final String name;
  final bool isMine;
  const _MentionInlineChip({required this.name, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final bg = isMine
        ? Colors.white.withOpacity(0.22)
        : AppColors.primaryMid.withOpacity(0.10);
    final fg = isMine ? Colors.white : AppColors.primaryMid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '@$name',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Composer — sticky bottom text field + send button.
// Wrapped in a SafeArea so the home indicator doesn't overlap on iOS.
// ═══════════════════════════════════════════════════════════════════

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(top: BorderSide(color: colors.gray100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Balanced padding — the old 10/8/8/8 was lopsided and crammed
          // the input against one side in RTL layouts. 12/8/12/8 gives the
          // row symmetric breathing room.
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            // `end` was for multi-line (pin Send to the bottom), but made
            // single-line composers look off-balance. `center` keeps the
            // Send button vertically centered with whatever height the
            // input currently has — feels right in both states.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                // No border / frame around the input — just a filled pill
                // that reads as a soft surface to type on. The
                // InputDecoration explicitly disables `border`,
                // `enabledBorder`, `focusedBorder`, `errorBorder` etc. so
                // the app-wide `InputDecorationTheme` doesn't paint a
                // rectangle on top of our rounded pill.
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      height: 1.3,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...'.tr(context),
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: colors.textDisabled,
                      ),
                      // Kill every border state so nothing paints on top of
                      // the pill, regardless of focus/error/disabled state.
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              // Breathing room between the input pill and the send button —
              // the old 6 px made them read as one cramped unit.
              const SizedBox(width: 8),
              _SendButton(
                isSending: isSending,
                onTap: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onTap;

  const _SendButton({required this.isSending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryMid,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      // Subtle elevation lifts the button off the composer surface so it
      // reads as the primary action, not just another pill.
      elevation: 1.5,
      child: InkWell(
        onTap: isSending ? null : onTap,
        // Same side length as the input (42 px) so the two widgets align
        // perfectly in the row — no floating half-pixel gap above/below.
        child: SizedBox(
          width: 42,
          height: 42,
          child: isSending
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
        ),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.bgCard,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 16, color: colors.textDisabled),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Comments are read-only here'.tr(context),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Mention popup — overlays the BOTTOM of the message list, just above
// the composer. Server-driven candidate list (priority ordered).
// ═══════════════════════════════════════════════════════════════════

class _MentionPopup extends ConsumerStatefulWidget {
  final int taskId;
  final void Function(MentionCandidate) onPick;
  final VoidCallback onClose;

  const _MentionPopup({
    required this.taskId,
    required this.onPick,
    required this.onClose,
  });

  @override
  ConsumerState<_MentionPopup> createState() => _MentionPopupState();
}

class _MentionPopupState extends ConsumerState<_MentionPopup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(mentionCandidatesProvider(widget.taskId).notifier)
          .loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(mentionCandidatesProvider(widget.taskId));
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(
          top: BorderSide(color: colors.gray200),
          bottom: BorderSide(color: colors.gray100),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar — also a visual cue for the user that the popup is
          // active and they can dismiss with the X.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.alternate_email_rounded,
                    size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mention someone'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.gray100),
          Flexible(
            child: _PopupBody(
              state: state,
              onPick: widget.onPick,
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupBody extends StatelessWidget {
  final MentionCandidatesState state;
  final void Function(MentionCandidate) onPick;

  const _PopupBody({required this.state, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          state.error!,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No matches'.tr(context),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: state.items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colors.gray100, indent: 56),
      itemBuilder: (_, i) {
        final c = state.items[i];
        return _CandidateRow(candidate: c, onTap: () => onPick(c));
      },
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final MentionCandidate candidate;
  final VoidCallback onTap;

  const _CandidateRow({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final roleColor = candidate.role != null
        ? _parseHex(candidate.role!.color)
        : colors.gray400;
    final initial =
        candidate.name.isNotEmpty ? candidate.name.characters.first : '?';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            // Avatar fallback to colored initial — matches role color so the
            // priority ordering reads at a glance.
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: roleColor.withOpacity(0.5), width: 1.5),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: roleColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (candidate.role != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        candidate.role!.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (candidate.isPriority)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Icon(Icons.star_rounded,
                    size: 14, color: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty / error / search-field widgets — same style as time logs tab.
// ═══════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  final bool hasFilter;
  final bool canAdd;
  const _EmptyView({required this.hasFilter, required this.canAdd});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'No comments'.tr(context),
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
              hasFilter
                  ? 'Try different keywords'.tr(context)
                  : (canAdd
                      ? 'Be the first to comment'.tr(context)
                      : 'No comments on this task yet'.tr(context)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: colors.textMuted,
              ),
            ),
          ],
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextFormField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 14,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Search comments...'.tr(context),
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
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              suffixIcon: hasText
                  ? GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, left: 4),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
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
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          );
        },
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
// Helpers — date grouping, hex parsing, date/time formatting.
// ═══════════════════════════════════════════════════════════════════

/// Walks [ordered] (oldest → newest) and produces a flat list of date
/// dividers + message items so the renderer doesn't need any per-frame
/// grouping logic.
List<_ChatItem> _groupByDate(List<Comment> ordered, BuildContext context) {
  final result = <_ChatItem>[];
  DateTime? lastDay;
  for (final c in ordered) {
    final created = c.createdAt;
    if (created != null) {
      final day = DateTime(created.year, created.month, created.day);
      if (lastDay != day) {
        result.add(_DateDividerItem(_formatDateHeader(day, context)));
        lastDay = day;
      }
    }
    result.add(_MessageItem(c));
  }
  return result;
}

sealed class _ChatItem {
  const _ChatItem();
}

class _DateDividerItem extends _ChatItem {
  final String label;
  const _DateDividerItem(this.label);
}

class _MessageItem extends _ChatItem {
  final Comment comment;
  const _MessageItem(this.comment);
}

bool _isWhitespace(String ch) =>
    ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';

/// Small colored pill showing the comment author's current role in the task
/// (e.g. "مدير المشروع", "مسؤول المهمة", "عضو في المهمة", "ليس عضو").
class _RoleBadge extends StatelessWidget {
  final CommentAuthorRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(role.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}

/// "10:23 م" — 12-hour clock with AM/PM in the current app language,
/// rendered in the user's *device* timezone.
///
/// The server ships `created_at` as an ISO-8601 string with a UTC offset
/// (e.g. `…+03:00`). Dart's `DateTime.parse` keeps the offset but still
/// exposes UTC on its internal clock; `.toLocal()` converts to whatever
/// the device is set to. `AppFuns.formatTime` then:
///   - produces `h:mm a` via Jiffy (locale-aware — "م" / "ص" in Arabic,
///     "AM" / "PM" in English),
///   - swaps any Arabic-Indic digits (`٠-٩`) to Western (`0-9`) so the
///     whole app stays consistent with the "English digits everywhere"
///     convention in MEMORY.md.
String _formatTime(DateTime? d) {
  if (d == null) return '';
  return AppFuns.formatTime(d.toLocal());
}

// Localized day-of-week + month names so we don't need to call
// `initializeDateFormatting('ar')` from main.dart. The list ordering
// matches DateTime.weekday (1=Mon..7=Sun) mapped via `weekday % 7` to put
// Sunday at index 0.

const _arDays = [
  'الأحد',
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];
const _arMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];
const _enDays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
const _enMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDateHeader(DateTime date, BuildContext context) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) return 'Today'.tr(context);
  if (dateOnly == yesterday) return 'Yesterday'.tr(context);

  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final dayIndex = date.weekday % 7; // Sun=0
  final monthIndex = date.month - 1;
  if (isArabic) {
    return '${_arDays[dayIndex]}، ${date.day} ${_arMonths[monthIndex]} ${date.year}';
  }
  return '${_enDays[dayIndex]}, ${_enMonths[monthIndex]} ${date.day}, ${date.year}';
}
