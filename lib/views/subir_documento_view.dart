import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Específico para descargas en Chrome (Flutter Web)
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SubirDocumentoClienteView extends StatefulWidget {
  final String clienteId; // ID del documento del cliente en Firestore

  const SubirDocumentoClienteView({super.key, required this.clienteId});

  @override
  State<SubirDocumentoClienteView> createState() => _SubirDocumentoClienteViewState();
}

class _SubirDocumentoClienteViewState extends State<SubirDocumentoClienteView> {
  bool _estaSubiendo = false;

  // 1. FUNCIÓN PARA SELECCIONAR Y SUBIR A FIRESTORE EN BASE64
  Future<void> _seleccionarYSubirArchivo() async {
    setState(() { _estaSubiendo = true; });

    try {
      // Abrir selector de archivos (PDF, imágenes)
      FilePickerResult? resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Vital en Flutter Web para leer los bytes
      );

      if (resultado != null && resultado.files.single.bytes != null) {
        PlatformFile archivo = resultado.files.single;

        Uint8List bytesArchivo = archivo.bytes!;
        String nombreArchivo = archivo.name;

        // Convertir bytes a texto Base64
        String base64String = base64Encode(bytesArchivo);

        // Guardar directamente en la subcolección 'documentos' de ese cliente
        await FirebaseFirestore.instance
            .collection('contador_clientes') // Colección principal de clientes
            .doc(widget.clienteId)
            .collection('documentos')
            .add({
          'nombre_archivo': nombreArchivo,
          'archivo_base64': base64String,
          'fecha_subida': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Documento guardado con éxito en Firestore!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir el archivo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _estaSubiendo = false; });
      }
    }
  }

  // 2. FUNCIÓN PARA DESCARGAR / VER EL ARCHIVO DESDE FIRESTORE
  void _descargarArchivo(String base64String, String nombreArchivo) {
    try {
      Uint8List bytes = base64Decode(base64String);

      // Crear enlace temporal de descarga en el navegador Chrome
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      // ignore: unused_local_variable
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", nombreArchivo)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint("Error al descargar archivo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón para subir archivos
          ElevatedButton.icon(
            onPressed: _estaSubiendo ? null : _seleccionarYSubirArchivo,
            icon: _estaSubiendo
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            label: Text(_estaSubiendo ? 'Subiendo documento...' : 'Subir PDF o Comprobante'),
          ),
          const SizedBox(height: 20),
          const Text('Documentos del cliente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          // Lista en tiempo real de los documentos guardados en Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contador_clientes')
                  .doc(widget.clienteId)
                  .collection('documentos')
                  .orderBy('fecha_subida', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No hay documentos subidos todavía.');
                }

                var documentos = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    var docData = documentos[index].data() as Map<String, dynamic>;
                    String nombre = docData['nombre_archivo'] ?? 'Sin nombre';
                    String base64Str = docData['archivo_base64'] ?? '';

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                        title: Text(nombre),
                        trailing: IconButton(
                          icon: const Icon(Icons.download, color: Colors.green),
                          tooltip: 'Descargar / Ver',
                          onPressed: () => _descargarArchivo(base64Str, nombre),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}