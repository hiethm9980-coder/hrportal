// Mobile / desktop implementation of the attachment storage helpers.
//
// This file is loaded only when `dart:io` is available (Android, iOS,
// macOS, Windows, Linux). On Web, `attachment_web.dart` is loaded instead
// via the conditional import in `attachment_service.dart`.

import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Resolve `<temporaryCacheDir>/attachments/<filename>`.
Future<String> getCachePath(String filename) async {
  final dir = await getTemporaryDirectory();
  final folder = Directory('${dir.path}/attachments');
  if (!folder.existsSync()) folder.createSync(recursive: true);
  return '${folder.path}/$filename';
}

bool fileExistsAt(String path) => File(path).existsSync();

/// Download `url` to `savePath` using a raw `HttpClient`.
///
/// We use dart:io directly (instead of Dio) because Dio strictly enforces
/// `Content-Length` and throws "Connection closed while receiving" when the
/// server lies about it (common with Laravel `Storage::download()` behind
/// certain serve configurations).
///
/// If the connection drops mid-stream but >=99% of the announced
/// Content-Length has already been written, the partial file is kept and
/// considered successful.
Future<String> downloadToFile({
  required String url,
  required String savePath,
  String? bearerToken,
  void Function(int received, int total)? onProgress,
}) async {
  // ignore: avoid_print
  print('┌── DOWNLOAD ─────────────────────────────────');
  // ignore: avoid_print
  print('│ URL       : $url');
  // ignore: avoid_print
  print('│ Save path : $savePath');
  // ignore: avoid_print
  print('└─────────────────────────────────────────────');

  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 30);

  final f = File(savePath);
  IOSink? sink;
  int received = 0;
  int? expectedContentLength;

  try {
    final req = await httpClient.getUrl(Uri.parse(url));
    req.headers.set('Accept', '*/*');
    req.headers.set('Connection', 'close');
    if (bearerToken != null && bearerToken.isNotEmpty) {
      req.headers.set('Authorization', 'Bearer $bearerToken');
    }

    final res = await req.close();
    // ignore: avoid_print
    print('│ Status     : ${res.statusCode}');
    // ignore: avoid_print
    print('│ Resp head  : ${res.headers}');
    expectedContentLength = res.contentLength > 0 ? res.contentLength : null;
    final total = res.contentLength;

    if (res.statusCode < 200 || res.statusCode >= 400) {
      throw HttpException('HTTP ${res.statusCode} ${res.reasonPhrase}');
    }

    if (f.existsSync()) f.deleteSync();
    sink = f.openWrite();

    await for (final chunk in res) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        final pct = ((received / total) * 100).toStringAsFixed(1);
        // ignore: avoid_print
        print('│ progress: $received / $total bytes ($pct%)');
      } else {
        // ignore: avoid_print
        print('│ progress: $received bytes');
      }
      onProgress?.call(received, total);
    }

    await sink.flush();
    await sink.close();
    sink = null;

    final fileSize = f.existsSync() ? f.lengthSync() : 0;
    // ignore: avoid_print
    print('┌── DOWNLOAD DONE ────────────────────────────');
    // ignore: avoid_print
    print('│ Received  : $received bytes');
    // ignore: avoid_print
    print('│ File size : $fileSize bytes');
    // ignore: avoid_print
    print('│ Expected  : ${expectedContentLength ?? "(unknown)"}');
    // ignore: avoid_print
    print('└─────────────────────────────────────────────');
    return savePath;
  } catch (err, st) {
    try {
      await sink?.flush();
      await sink?.close();
    } catch (_) {}
    sink = null;

    final fileSize = f.existsSync() ? f.lengthSync() : 0;

    // Recovery: server cut the connection mid-stream but we already wrote
    // bytes. Accept the file if >=99% of the announced size is on disk.
    final closeEnough = expectedContentLength == null
        ? fileSize > 0
        : fileSize >= (expectedContentLength * 0.99).floor();

    if (fileSize > 0 && closeEnough) {
      // ignore: avoid_print
      print('┌── DOWNLOAD RECOVERED ───────────────────────');
      // ignore: avoid_print
      print('│ Note      : Connection error after data received');
      // ignore: avoid_print
      print('│ Error     : $err');
      // ignore: avoid_print
      print('│ File size : $fileSize bytes');
      // ignore: avoid_print
      print('│ Expected  : ${expectedContentLength ?? "(unknown)"}');
      // ignore: avoid_print
      print('└─────────────────────────────────────────────');
      return savePath;
    }

    // ignore: avoid_print
    print('┌── DOWNLOAD ERROR ───────────────────────────');
    // ignore: avoid_print
    print('│ err download $url: $err');
    // ignore: avoid_print
    print('│ File size : $fileSize bytes');
    // ignore: avoid_print
    print('│ Expected  : ${expectedContentLength ?? "(unknown)"}');
    // ignore: avoid_print
    print('│ Stack     :\n$st');
    // ignore: avoid_print
    print('└─────────────────────────────────────────────');
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    rethrow;
  } finally {
    try {
      await sink?.close();
    } catch (_) {}
    httpClient.close(force: true);
  }
}

/// Open a previously-downloaded file with the OS default app.
Future<void> openLocalFileAt(String localFilePath) async {
  final result = await OpenFilex.open(localFilePath);
  if (result.type != ResultType.done) {
    throw Exception('Could not open file: ${result.message}');
  }
}
