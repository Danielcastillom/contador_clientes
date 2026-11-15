import 'package:url_launcher/url_launcher.dart';

Future<void> downloadOrOpenFile({
  required String fileName,
  required String base64String,
  required String fileUrl,
}) async {
  if (fileUrl.isNotEmpty) {
    Uri uri = Uri.parse(fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
    return;
  }

  if (base64String.isNotEmpty) {
    String cleanBase64 = base64String.trim();
    if (cleanBase64.contains(',')) {
      cleanBase64 = cleanBase64.split(',').last;
    }
    cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');

    String ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    String mimeType = 'application/octet-stream';
    if (ext == 'pdf') {
      mimeType = 'application/pdf';
    } else if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mimeType = 'image/jpeg';
    }

    String dataUrl = 'data:$mimeType;base64,$cleanBase64';
    Uri uri = Uri.parse(dataUrl);

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      await launchUrl(uri);
    }
  }
}
