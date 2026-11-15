import 'dart:convert' as convert;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadOrOpenFile({
  required String fileName,
  required String base64String,
  required String fileUrl,
}) async {
  if (fileUrl.isNotEmpty) {
    html.AnchorElement(href: fileUrl)
      ..target = '_blank'
      ..setAttribute("download", fileName)
      ..click();
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

    try {
      List<int> bytes = convert.base64Decode(cleanBase64);
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..target = '_blank'
        ..setAttribute("download", fileName)
        ..click();

      // Dar tiempo suficiente al navegador para procesar la descarga antes de revocar la URL del Blob
      Future.delayed(const Duration(seconds: 30), () {
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      throw Exception("Error al procesar el archivo base64: $e");
    }
  }
}
