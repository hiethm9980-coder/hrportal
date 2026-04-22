import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../../data/models/attachment_models.dart';
import '../../../providers/attachments_provider.dart';

/// "Attachments" tab of the task detail screen.
///
/// Same WhatsApp-style mental model as the Comments tab:
///   ┌─────────────────────────────────┐
///   │ Header (back · title · search)  │  ← navy gradient
///   ├─────────────────────────────────┤
///   │   ─── Saturday, Apr 17 ─────   │  ← date divider
///   │  [📄  report.pdf      9:35 م] │
///   │  [🖼  screenshot.png  9:40 م] │
///   │                                 │
///   │   ─── Today ─────────────────   │
///   │  [📄  notes.pdf       10:22 م] │
///   ├─────────────────────────────────┤
///   │  [📎 إضافة مرفق]                │  ← FAB
///   └─────────────────────────────────┘
///
/// All times come from the server as UTC+03 ISO-8601 strings. We parse
/// them into `DateTime` (which preserves the offset), then `.toLocal()`
/// at display time — every user sees times in their own device timezone.
class AttachmentsTab extends ConsumerStatefulWidget {
  final int taskId;
  final String? initialTitle;

  const AttachmentsTab({super.key, required this.taskId, this.initialTitle});

  @override
  ConsumerState<AttachmentsTab> createState() => _AttachmentsTabState();
}

class _AttachmentsTabState extends ConsumerState<AttachmentsTab> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attachmentsProvider(widget.taskId).notifier).load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Header actions ────────────────────────────────────────────────

  void _toggleSearch() => setState(() {
    _showSearch = !_showSearch;
    if (!_showSearch) {
      _searchController.clear();
      _searchQuery = '';
    }
  });

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = v.trim().toLowerCase());
    });
  }

  Future<void> _refresh() async {
    await ref.read(attachmentsProvider(widget.taskId).notifier).load();
  }

  // ── Upload ────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    // `file_picker: ^11` exposes pickFiles as a static directly on
    // `FilePicker` (the old `FilePicker.platform.pickFiles` was removed).
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'webp', 'jpg', 'jpeg', 'png', 'zip'],
      allowMultiple: false,
      withData: false, // we only need the path; avoids loading bytes
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) return;

    // Belt-and-suspenders client-side size check (server also enforces).
    if (picked.size > 10 * 1024 * 1024) {
      if (!mounted) return;
      _showError('File exceeds 10 MB'.tr(context));
      return;
    }

    try {
      await ref
          .read(attachmentsProvider(widget.taskId).notifier)
          .upload(filePath: path, filename: picked.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment uploaded'.tr(context)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  // Download + open is handled per-card by `_AttachmentCard` itself so
  // each row tracks its own cache-existence + downloading state. The tab
  // only worries about upload / refresh / delete.

  // ── Delete ────────────────────────────────────────────────────────

  Future<void> _confirmDelete(TaskAttachment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete attachment'.tr(ctx),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          'Are you sure you want to delete this attachment?'.tr(ctx),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel'.tr(ctx),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
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
    if (confirmed != true || !mounted) return;

    final successText = 'Attachment deleted'.tr(context);
    try {
      await ref.read(attachmentsProvider(widget.taskId).notifier).delete(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successText),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted)
        GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attachmentsProvider(widget.taskId));

    // Apply search filter on the fly — server doesn't support `q` for
    // attachments so we filter locally. Cheap since attachment lists are
    // small and the filter is O(n).
    final filtered = _searchQuery.isEmpty
        ? state.attachments
        : state.attachments
              .where((a) => a.name.toLowerCase().contains(_searchQuery))
              .toList();

    final canUpload = state.summary.canUpload;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              heroTag: 'attach-fab-${widget.taskId}',
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
          onPressed: (state.isUploading || state.isMutating)
              ? null
              : _pickAndUpload,
          icon: state.isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(Icons.attach_file_rounded),
              label: Text(
                state.isUploading
                    ? 'Uploading...'.tr(context)
                    : 'Add attachment'.tr(context),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                parentTitle: widget.initialTitle ?? '',
                count: state.summary.count,
                showSearch: _showSearch,
                searchController: _searchController,
                searchActive: _searchQuery.isNotEmpty,
                onBack: () => Navigator.of(context).maybePop(),
                onToggleSearch: _toggleSearch,
                onRefresh: _refresh,
                onSearchChanged: _onSearchChanged,
              ),
              Expanded(
                child: state.isLoading && state.attachments.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null && state.attachments.isEmpty
                        ? _ErrorView(
                            message: state.error!, onRetry: _refresh)
                        : filtered.isEmpty
                            ? _EmptyView(
                                isFiltered: _searchQuery.isNotEmpty,
                                canUpload: canUpload,
                              )
                            : _AttachmentsList(
                                // Server already sorts newest-first (and uses
                                // `id DESC` as a tiebreaker for same-second
                                // uploads), so we pass the list straight
                                // through — no client-side re-sort. Files
                                // read like an inbox: most recent at the top.
                                items: filtered,
                                onDelete: _confirmDelete,
                                onRefresh: _refresh,
                                bottomPad: canUpload ? 96 : 24,
                              ),
              ),
            ],
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String parentTitle;
  final int count;
  final bool showSearch;
  final bool searchActive;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.parentTitle,
    required this.count,
    required this.showSearch,
    required this.searchActive,
    required this.searchController,
    required this.onBack,
    required this.onToggleSearch,
    required this.onRefresh,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: showSearch ? 12 : 14,
        left: 14,
        right: 14,
      ),
      child: Column(
        children: [
          // Header row layout — matches the Comments tab:
          //   [back] [title + subtitle (Expanded)] [search] [refresh]
          // Row auto-flips in RTL, so the back button lands on the right
          // (start) and the action icons on the left (end) for Arabic.
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
                          'Attachments'.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              AppFuns.replaceArabicNumbers('$count'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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
                    ),
                  )
                : const SizedBox.shrink(),
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
      child: Container(
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: TextField(
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
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintText: 'Search attachments...'.tr(context),
          hintStyle: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// List + date grouping
// ═══════════════════════════════════════════════════════════════════

/// One row in the grouped list — either a date header or a file card.
sealed class _ListRow {
  const _ListRow();
}

class _DateHeader extends _ListRow {
  final DateTime day;
  const _DateHeader(this.day);
}

class _FileRow extends _ListRow {
  final TaskAttachment attachment;
  const _FileRow(this.attachment);
}

class _AttachmentsList extends StatelessWidget {
  final List<TaskAttachment> items;
  final void Function(TaskAttachment) onDelete;
  final Future<void> Function() onRefresh;
  final double bottomPad;

  const _AttachmentsList({
    required this.items,
    required this.onDelete,
    required this.onRefresh,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _groupByDay(items);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          if (row is _DateHeader) {
            return _DayDivider(day: row.day);
          }
          final file = (row as _FileRow).attachment;
          return _AttachmentCard(
            // `ValueKey(id)` is critical: we're about to make the card
            // stateful with per-attachment cache-existence state. The key
            // ensures Flutter preserves that state even when the list
            // re-renders (e.g. after an upload splices a new row).
            key: ValueKey('att-${file.id}'),
            attachment: file,
            onDelete: file.canDelete ? () => onDelete(file) : null,
          );
        },
      ),
    );
  }

  /// Walks the chronological list and slots in a date header whenever the
  /// local-timezone calendar date changes.
  List<_ListRow> _groupByDay(List<TaskAttachment> sorted) {
    final out = <_ListRow>[];
    DateTime? lastDay;
    for (final a in sorted) {
      final created = a.createdAt;
      if (created == null) {
        out.add(_FileRow(a));
        continue;
      }
      final local = created.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || day != lastDay) {
        out.add(_DateHeader(day));
        lastDay = day;
      }
      out.add(_FileRow(a));
    }
    return out;
  }
}

class _DayDivider extends StatelessWidget {
  final DateTime day;
  const _DayDivider({required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: colors.gray100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _formatDayLabel(context, day),
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
// Attachment card
// ═══════════════════════════════════════════════════════════════════

/// One attachment row. Self-manages its local cache state:
///   - On mount: asks [AttachmentService] whether the file is already on
///     disk; if so, flips into "open file" mode (green folder icon).
///   - On tap: downloads then opens; updates the icon to "open" once the
///     cached file exists.
///   - On long-press: invokes [onDelete] (if the attachment is deletable).
///
/// This mirrors the Leaves screen's download-or-open pattern 1:1 — same
/// icons, same colors — so the two features feel consistent.
class _AttachmentCard extends ConsumerStatefulWidget {
  final TaskAttachment attachment;
  final VoidCallback? onDelete;

  const _AttachmentCard({super.key, required this.attachment, this.onDelete});

  @override
  ConsumerState<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends ConsumerState<_AttachmentCard> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  /// Stable cache key — matches what we pass to `AttachmentService.download`.
  /// Must be the SAME in both exists() + download() calls so the existence
  /// check and the actual file end up at the same path.
  String get _cacheKey => 'task-attach-${widget.attachment.id}';

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so the first frame renders the download icon
    // immediately, then swaps to "open" if the file is already cached —
    // this avoids a briefly-wrong icon during the async check.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExists());
  }

  Future<void> _checkExists() async {
    if (kIsWeb) return; // Web has no local cache — always "download".
    try {
      final svc = ref.read(attachmentServiceProvider);
      final path = await svc.localPath(
        key: _cacheKey,
        attachmentPath: widget.attachment.downloadUrl,
      );
      final ok = await svc.exists(
        key: _cacheKey,
        attachmentPath: widget.attachment.downloadUrl,
      );
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _exists = ok;
      });
    } catch (_) {
      // Silent — the UI falls back to the "download" icon which is still
      // a valid path forward for the user.
    }
  }

  Future<void> _onTap() async {
    if (_downloading) return;
    final svc = ref.read(attachmentServiceProvider);

    // Already on disk → just open it.
    if (!kIsWeb && _exists && _localPath != null) {
      try {
        await svc.openLocal(_localPath!);
      } catch (e) {
        if (mounted) _showError(e.toString());
      }
      return;
    }

    setState(() => _downloading = true);
    try {
      final saved = await svc.download(
        key: _cacheKey,
        attachmentPath: widget.attachment.downloadUrl,
      );
      if (!mounted) return;
      if (saved == null) {
        // Web — no filesystem, just open the URL in a new tab.
        await svc.openInBrowser(widget.attachment.downloadUrl);
      } else {
        setState(() {
          _localPath = saved;
          _exists = true;
        });
        await svc.openLocal(saved);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final attachment = widget.attachment;
    final role = attachment.uploaderRole;
    final createdLocal = attachment.createdAt?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.gray100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                // Stretch + bounded height: see IntrinsicHeight.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _FileIcon(extension: attachment.extension),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (attachment.sizeLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              attachment.sizeLabel,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                          if (attachment.uploader != null) ...[
                            SizedBox(
                              height: attachment.sizeLabel.isNotEmpty ? 6 : 4,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    attachment.uploader!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (role != null) ...[
                                  const SizedBox(width: 6),
                                  _RoleTag(role: role),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // End-aligned column only as wide as the action row: avoids
                  // stretch + full-width inner Rows (infinite max width in layout).
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: createdLocal != null
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onDelete != null) ...[
                            _DeleteIconBtn(onTap: widget.onDelete!),
                            const SizedBox(width: 8),
                          ],
                          _TrailingAction(
                            isDownloading: _downloading,
                            showOpen: !kIsWeb && _exists,
                          ),
                        ],
                      ),
                      if (createdLocal != null)
                        Text(
                          AppFuns.formatTime(createdLocal),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  final String extension;
  const _FileIcon({required this.extension});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor(extension);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 22),
    );
  }

  (IconData, Color) _iconAndColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return (Icons.picture_as_pdf_rounded, const Color(0xFFDC2626));
      case 'zip':
        return (Icons.folder_zip_rounded, const Color(0xFFF59E0B));
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return (Icons.image_rounded, const Color(0xFF7C3AED));
      default:
        return (Icons.insert_drive_file_rounded, const Color(0xFF64748B));
    }
  }
}

/// Small red trash-can button. Only rendered when the backend said the
/// current user can delete this attachment (`can_delete: true` — i.e.
/// the uploader or the project manager). The nested `InkWell` consumes
/// the tap so it doesn't bubble up to the card's download/open handler.
class _DeleteIconBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteIconBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

/// Three-state trailing action — matches the Leaves screen pattern:
///   - `isDownloading == true`         → spinner on a primary-tinted bg
///   - `showOpen    == true`           → green folder-open icon (cached)
///   - otherwise                       → primary download icon
class _TrailingAction extends StatelessWidget {
  final bool isDownloading;
  final bool showOpen;

  const _TrailingAction({required this.isDownloading, required this.showOpen});

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryMid.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryMid),
        ),
      );
    }
    final color = showOpen ? AppColors.success : AppColors.primaryMid;
    final icon = showOpen
        ? Icons.folder_open_rounded
        : Icons.file_download_outlined;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Small colored pill for the uploader's role in this task.
class _RoleTag extends StatelessWidget {
  final AttachmentUploaderRole role;
  const _RoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(role.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty / error states
// ═══════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  final bool isFiltered;
  final bool canUpload;
  const _EmptyView({required this.isFiltered, required this.canUpload});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file_rounded,
              size: 56,
              color: colors.textDisabled,
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered
                  ? 'No results'.tr(context)
                  : 'No attachments'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Try different keywords'.tr(context)
                  : (canUpload
                        ? 'Upload the first file'.tr(context)
                        : 'No files have been attached yet'.tr(context)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
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
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colors.textDisabled,
            ),
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

/// "Today" / "Yesterday" for recent dates, otherwise a full localized
/// form (e.g. "السبت، 17 أبريل 2026"). Uses AppFuns for localized
/// day/month names + Western digits.
String _formatDayLabel(BuildContext context, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today'.tr(context);
  if (day == yesterday) return 'Yesterday'.tr(context);
  return AppFuns.formatDate(day);
}

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}
