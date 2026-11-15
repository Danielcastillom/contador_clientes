import 'dart:convert' as convert;
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadOrOpenFile({
  required String fileName,
  required String base64String,
  required String fileUrl,
}) async {
  // 1. Si hay una URL de archivo web/pública, intentar abrirla
  if (fileUrl.isNotEmpty) {
    try {
      Uri uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
  }

  // 2. Si hay datos en Base64, decodificar y guardar en el sistema de archivos local
  if (base64String.isNotEmpty) {
    try {
      String cleanBase64 = base64String.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');

      List<int> bytes = convert.base64Decode(cleanBase64);

      // Limpiar el nombre de archivo para evitar caracteres no soportados en Windows
      String safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (safeName.isEmpty) safeName = 'documento.pdf';

      // Guardar en la carpeta temporal del sistema
      Directory tempDir = Directory.systemTemp;
      String filePath = '${tempDir.path}${Platform.pathSeparator}$safeName';

      File localFile = File(filePath);
      await localFile.writeAsBytes(bytes, flush: true);

      // Abrir el archivo en Windows o Escritorio con el programa predeterminado (Adobe, Edge, Visor de fotos, etc.)
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', filePath], runInShell: true);
      } else {
        Uri fileUri = Uri.file(filePath);
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          await Process.run('open', [filePath]);
        }
      }
    } catch (e) {
      throw Exception('Error al descargar o abrir el archivo en el sistema: $e');
    }
  }
}
