// Web stub for the attachment storage helpers.
//
// On Web there is no local filesystem and no native "open file" support,
// so all helpers are no-ops. The main service uses [openInBrowser] on Web
// instead, which simply launches the URL in a new browser tab via
// url_launcher.

Future<String> getCachePath(String filename) async {
  throw UnsupportedError('Local cache is not available on Web');
}

bool fileExistsAt(String path) => false;

Future<String> downloadToFile({
  required String url,
  required String savePath,
  String? bearerToken,
  void Function(int received, int total)? onProgress,
}) async {
  throw UnsupportedError('Direct file download is not available on Web');
}

Future<void> openLocalFileAt(String localFilePath) async {
  throw UnsupportedError('Opening local files is not available on Web');
}
