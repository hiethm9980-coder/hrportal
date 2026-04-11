import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';

// Conditional import: on Web we use the no-op stub. On all other platforms
// (Android, iOS, macOS, Windows, Linux) we use the dart:io implementation.
import 'attachment_web.dart'
    if (dart.library.io) 'attachment_io.dart' as platform;

/// Generic file-attachment download service.
///
/// Used for any feature that needs to download a file referenced by an
/// `attachment_path` returned from the API (leave requests, employee
/// requests, payroll attachments, etc).
///
/// Cross-platform behavior:
///
/// | Platform        | Behavior                                            |
/// |-----------------|-----------------------------------------------------|
/// | Android / iOS   | Download to app cache (no permissions), open with  |
/// |                 | native viewer via `open_filex`.                     |
/// | Web             | `download()` is a no-op. UI should call            |
/// |                 | `openInBrowser()` to launch the URL in a new tab.   |
/// | macOS / Windows | Same as mobile (uses `path_provider` cache).        |
///
/// Filename format: `<key>.<ext>` where `key` is typically a request number
/// (e.g. `LR-26-00005.jpg`) or a synthetic id (e.g. `req-42.pdf`).
class AttachmentService {
  final SecureTokenStorage _storage;

  AttachmentService({
    required SecureTokenStorage storage,
  }) : _storage = storage;

  /// Build full URL: `base_url + attachment_path`.
  String buildUrl(String attachmentPath) {
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final path =
        attachmentPath.startsWith('/') ? attachmentPath : '/$attachmentPath';
    return '$base$path';
  }

  /// Extract file extension from a path/URL (without the dot).
  String extensionOf(String pathOrUrl) {
    final cleaned = pathOrUrl.split('?').first.split('#').first;
    final lastDot = cleaned.lastIndexOf('.');
    final lastSlash = cleaned.lastIndexOf('/');
    if (lastDot > lastSlash && lastDot != -1) {
      final ext = cleaned.substring(lastDot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    return 'bin';
  }

  String _filename(String key, String attachmentPath) {
    return '$key.${extensionOf(attachmentPath)}';
  }

  /// Resolve the local cache path for a given attachment.
  /// Returns `null` on Web (no local filesystem).
  Future<String?> localPath({
    required String key,
    required String attachmentPath,
  }) async {
    if (kIsWeb) return null;
    return platform.getCachePath(_filename(key, attachmentPath));
  }

  /// Whether the attachment is already downloaded to the local cache.
  /// Always `false` on Web.
  Future<bool> exists({
    required String key,
    required String attachmentPath,
  }) async {
    if (kIsWeb) return false;
    final path = await localPath(key: key, attachmentPath: attachmentPath);
    if (path == null) return false;
    return platform.fileExistsAt(path);
  }

  /// Download the attachment to the cache directory.
  /// On Web this is a no-op — call [openInBrowser] instead.
  Future<String?> download({
    required String key,
    required String attachmentPath,
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) return null;

    final savePath =
        await localPath(key: key, attachmentPath: attachmentPath);
    if (savePath == null) return null;

    final url = buildUrl(attachmentPath);

    String? token;
    try {
      token = await _storage.getToken();
    } catch (_) {}

    return platform.downloadToFile(
      url: url,
      savePath: savePath,
      bearerToken: token,
      onProgress: onProgress,
    );
  }

  /// Open a previously-downloaded file with the OS default app.
  /// No-op on Web.
  Future<void> openLocal(String localFilePath) async {
    if (kIsWeb) return;
    await platform.openLocalFileAt(localFilePath);
  }

  /// Open the attachment directly in a browser tab. Used as the primary
  /// open mechanism on Web, and as a fallback elsewhere.
  Future<void> openInBrowser(String attachmentPath) async {
    final url = buildUrl(attachmentPath);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) throw Exception('Could not open link');
  }
}
