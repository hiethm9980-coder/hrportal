import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
import 'package:hr_portal/features/tasks/data/models/attachment_models.dart';
import 'package:hr_portal/features/tasks/data/models/project_document_models.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';

import '../providers/project_documents_provider.dart';

/// Attachments sub-tab for the project screen — mirrors the task
/// [AttachmentsTab] (grouped by day, uploader + role, download, FAB when allowed).
class ProjectDocumentsTabContent extends ConsumerStatefulWidget {
  final int projectId;
  final String projectName;
  final String projectCode;
  final VoidCallback onBack;

  const ProjectDocumentsTabContent({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectCode = '',
    required this.onBack,
  });

  @override
  ConsumerState<ProjectDocumentsTabContent> createState() =>
      _ProjectDocumentsTabContentState();
}

class _ProjectDocumentsTabContentState
    extends ConsumerState<ProjectDocumentsTabContent> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectDocumentsProvider(widget.projectId).notifier).load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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
    await ref.read(projectDocumentsProvider(widget.projectId).notifier).load();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'webp', 'jpg', 'jpeg', 'png', 'zip'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) return;

    if (picked.size > 10 * 1024 * 1024) {
      if (!mounted) return;
      _snack('File exceeds 10 MB'.tr(context), isError: true);
      return;
    }

    try {
      await ref
          .read(projectDocumentsProvider(widget.projectId).notifier)
          .upload(filePath: path, filename: picked.name);
      if (!mounted) return;
      _snack('Attachment uploaded'.tr(context), isError: false);
    } catch (e) {
      if (!mounted) return;
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete(ProjectDocumentItem a) async {
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

    try {
      await ref
          .read(projectDocumentsProvider(widget.projectId).notifier)
          .delete(a.id);
      if (!mounted) return;
      _snack('Attachment deleted'.tr(context), isError: false);
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectDocumentsProvider(widget.projectId));
    final canUpload = state.summary.canUpload;
    final subtitle = widget.projectCode.trim().isEmpty
        ? widget.projectName
        : '${widget.projectCode.trim()} · ${widget.projectName}';

    final filtered = _searchQuery.isEmpty
        ? state.documents
        : state.documents
              .where((a) => a.displayName.toLowerCase().contains(_searchQuery))
              .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              heroTag: 'project-docs-fab-${widget.projectId}',
              backgroundColor: AppColors.primaryMid,
              foregroundColor: Colors.white,
              onPressed: state.isUploading ? null : _pickAndUpload,
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
      body: Column(
        children: [
          _DocsHeader(
            onBack: widget.onBack,
            count: state.summary.count,
            subtitle: subtitle,
            showSearch: _showSearch,
            searchActive: _searchQuery.isNotEmpty,
            searchController: _searchController,
            onToggleSearch: _toggleSearch,
            onRefresh: _refresh,
            onSearchChanged: _onSearchChanged,
          ),
          Expanded(
            child: ColoredBox(
              color: context.appColors.bg,
              child: state.isLoading && state.documents.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null && state.documents.isEmpty
                  ? _ErrorView(message: state.error!, onRetry: _refresh)
                  : filtered.isEmpty
                  ? _EmptyView(
                      isFiltered: _searchQuery.isNotEmpty,
                      canUpload: canUpload,
                    )
                  : _DocsList(
                      items: filtered,
                      onDelete: _confirmDelete,
                      onRefresh: _refresh,
                      bottomPad: canUpload ? 96 : 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header — same row model as [AttachmentsTab] (task) ───────────

class _DocsHeader extends StatelessWidget {
  final VoidCallback onBack;
  final int count;
  final String subtitle;
  final bool showSearch;
  final bool searchActive;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;

  const _DocsHeader({
    required this.onBack,
    required this.count,
    required this.subtitle,
    required this.showSearch,
    required this.searchActive,
    required this.searchController,
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
          Row(
            children: [
              _NavyIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
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
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
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
              _NavyIconBtn(
                icon: showSearch
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.search_rounded,
                active: !showSearch && searchActive,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 6),
              _NavyIconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
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

/// Same touch target as [AttachmentsTab]’s [`_IconBtn`].
class _NavyIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _NavyIconBtn({
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
        alignment: Alignment.center,
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

sealed class _ListRowH {
  const _ListRowH();
}

class _DateHeaderH extends _ListRowH {
  final DateTime day;
  const _DateHeaderH(this.day);
}

class _FileRowH extends _ListRowH {
  final ProjectDocumentItem doc;
  const _FileRowH(this.doc);
}

class _DocsList extends StatelessWidget {
  final List<ProjectDocumentItem> items;
  final void Function(ProjectDocumentItem) onDelete;
  final Future<void> Function() onRefresh;
  final double bottomPad;

  const _DocsList({
    required this.items,
    required this.onDelete,
    required this.onRefresh,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _groupByDay(items);
    return RefreshIndicator(
      color: AppColors.primaryMid,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          if (row is _DateHeaderH) {
            return _DayRow(day: row.day);
          }
          final file = (row as _FileRowH).doc;
          return _ProjectDocCard(
            key: ValueKey('pdoc-${file.id}'),
            document: file,
            onDelete: file.canDelete ? () => onDelete(file) : null,
          );
        },
      ),
    );
  }

  static List<_ListRowH> _groupByDay(List<ProjectDocumentItem> sorted) {
    final out = <_ListRowH>[];
    DateTime? lastDay;
    for (final a in sorted) {
      final created = a.createdAt;
      if (created == null) {
        out.add(_FileRowH(a));
        continue;
      }
      final local = created.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || day != lastDay) {
        out.add(_DateHeaderH(day));
        lastDay = day;
      }
      out.add(_FileRowH(a));
    }
    return out;
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  const _DayRow({required this.day});

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

String _formatDayLabel(BuildContext context, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today'.tr(context);
  if (day == yesterday) return 'Yesterday'.tr(context);
  return AppFuns.formatDate(day);
}

class _ProjectDocCard extends ConsumerStatefulWidget {
  final ProjectDocumentItem document;
  final VoidCallback? onDelete;

  const _ProjectDocCard({super.key, required this.document, this.onDelete});

  @override
  ConsumerState<_ProjectDocCard> createState() => _ProjectDocCardState();
}

class _ProjectDocCardState extends ConsumerState<_ProjectDocCard> {
  bool _downloading = false;
  bool _exists = false;
  String? _localPath;

  String get _cacheKey => 'project-doc-${widget.document.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExists());
  }

  Future<void> _checkExists() async {
    if (kIsWeb) return;
    if ((widget.document.downloadUrl ?? '').isEmpty) return;
    try {
      final svc = ref.read(attachmentServiceProvider);
      final path = await svc.localPath(
        key: _cacheKey,
        attachmentPath: widget.document.downloadUrl!,
      );
      final ok = await svc.exists(
        key: _cacheKey,
        attachmentPath: widget.document.downloadUrl!,
      );
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _exists = ok;
      });
    } catch (_) {}
  }

  Future<void> _onTap() async {
    if (_downloading) return;
    if ((widget.document.downloadUrl ?? '').isEmpty) return;
    final svc = ref.read(attachmentServiceProvider);
    if (!kIsWeb && _exists && _localPath != null) {
      try {
        await svc.openLocal(_localPath!);
      } catch (e) {
        if (mounted) _err(e.toString());
      }
      return;
    }

    setState(() => _downloading = true);
    try {
      final saved = await svc.download(
        key: _cacheKey,
        attachmentPath: widget.document.downloadUrl!,
      );
      if (!mounted) return;
      if (saved == null) {
        await svc.openInBrowser(widget.document.downloadUrl!);
      } else {
        setState(() {
          _localPath = saved;
          _exists = true;
        });
        await svc.openLocal(saved);
      }
    } catch (e) {
      if (mounted) _err(e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _err(String message) {
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
    final d = widget.document;
    final role = d.uploaderRole;
    final createdLocal = d.createdAt?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (d.downloadUrl ?? '').trim().isEmpty ? null : _onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            // ListView children get unbounded max height; without this, stretch
            // passes infinite height to Align and layout throws.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _FileTypeIcon(ext: d.extension),
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
                            d.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (d.sizeLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              d.sizeLabel,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                          if (d.uploader != null) ...[
                            SizedBox(height: d.sizeLabel.isNotEmpty ? 6 : 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    d.uploader!.name,
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
                                  _RolePill(role: role),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // No CrossAxisAlignment.stretch here: a stretched child Row
                  // with mainAxisSize.max would get infinite max width and fail.
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
                            _DeletePill(onTap: widget.onDelete!),
                            const SizedBox(width: 8),
                          ],
                          _TrailingPill(
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

/// Per-extension colors — same mapping as task [_FileIcon] on attachments.
class _FileTypeIcon extends StatelessWidget {
  final String ext;
  const _FileTypeIcon({required this.ext});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _ic(ext);
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

  (IconData, Color) _ic(String e) {
    switch (e.toLowerCase()) {
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

/// Mirrors [_DeleteIconBtn] in task [AttachmentsTab].
class _DeletePill extends StatelessWidget {
  final VoidCallback onTap;
  const _DeletePill({required this.onTap});

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

/// Same layout as task [_TrailingAction] (spinner / download / open cached).
class _TrailingPill extends StatelessWidget {
  final bool isDownloading;
  final bool showOpen;

  const _TrailingPill({required this.isDownloading, required this.showOpen});

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

/// Colored uploader role pill — same structure as task [_RoleTag].
class _RolePill extends StatelessWidget {
  final AttachmentUploaderRole role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final c = _parseRoleHex(role.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }
}

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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: context.appColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Retry'.tr(context),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseRoleHex(String hex) {
  if (hex.isEmpty) return const Color(0xFF9CA3AF);
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.isEmpty) return const Color(0xFF9CA3AF);
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final v = int.tryParse(withAlpha, radix: 16);
  if (v == null) return const Color(0xFF9CA3AF);
  return Color(v);
}
