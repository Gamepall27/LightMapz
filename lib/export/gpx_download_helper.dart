import 'gpx_download_helper_stub.dart'
    if (dart.library.html) 'gpx_download_helper_web.dart';

Future<void> downloadGpxFile({
  required String filename,
  required String content,
}) {
  return downloadGpxFileImpl(
    filename: filename,
    content: content,
  );
}
