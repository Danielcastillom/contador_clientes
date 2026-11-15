import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

Future<void> downloadFile({
  required String fileName,
  required String base64String,
  required String fileUrl,
}) async {
  await downloadOrOpenFile(
    fileName: fileName,
    base64String: base64String,
    fileUrl: fileUrl,
  );
}
