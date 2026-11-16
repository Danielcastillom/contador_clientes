import 'dart:convert' as convert;
import 'dart:typed_data';

/// Decodifica de forma segura cadenas Base64 evitando excepciones FormatException que cierran la app
Uint8List? safeBase64Decode(String? base64Str) {
  if (base64Str == null) return null;
  String clean = base64Str.trim();
  if (clean.isEmpty) return null;

  if (clean.contains(',')) {
    clean = clean.split(',').last;
  }
  clean = clean.replaceAll(RegExp(r'\s+'), '');
  if (clean.isEmpty) return null;

  try {
    return convert.base64Decode(clean);
  } catch (_) {
    return null;
  }
}
