import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDetailView extends StatefulWidget {
  final String clientId;
  final String clientEmail;

  const ClientDetailView({
    Key? key,
    required this.clientId,
    required this.clientEmail,
  }) : super(key: key);

  @override
  State<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends State<ClientDetailView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploading = false;

  Future<void> _uploadDocument(String recordId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true, // Vital para la web
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });

        PlatformFile file = result.files.first;
        String fileName = file.name;

        Reference ref = _storage.ref().child('clients/${widget.clientId}/documents/$fileName');
        UploadTask uploadTask;

        // En la web usamos exclusivamente los bytes en memoria para evitar el error de 'path'
        if (kIsWeb) {
          if (file.bytes != null) {
            uploadTask = ref.putData(file.bytes!);
          } else {
            throw Exception('No se pudieron leer los bytes del archivo en el navegador.');
          }
        } else {
          // En dispositivos móviles o escritorio usamos la ruta física
          if (file.path != null) {
            uploadTask = ref.putFile(File(file.path!));
          } else {
            throw Exception('Ruta de archivo no válida.');
          }
        }

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await _db
            .collection('clients')
            .doc(widget.clientId)
            .collection('monthly_records')
            .doc(recordId)
            .set({
          'documents': FieldValue.arrayUnion([
            {
              'title': fileName,
              'fileUrl': downloadUrl,
              'uploadedBy': 'accountant',
              'uploadedAt': Timestamp.now(),
            }
          ])
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Documento subido y asociado con éxito!')),
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
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace del archivo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cliente: ${widget.clientEmail}'),
        centerTitle: true,
      ),
      body: _isUploading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Subiendo documento a Firebase...'),
          ],
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('clients')
            .doc(widget.clientId)
            .collection('monthly_records')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay registros financieros para este cliente.'),
            );
          }

          final records = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: records.length,
            itemBuilder: (context, index) {
              var recordDoc = records[index];
              var data = recordDoc.data() as Map<String, dynamic>;
              String recordId = recordDoc.id;
              String monthTitle = data['month'] ?? recordId;
              String status = data['status'] ?? 'Pendiente';

              var documents = data['documents'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            monthTitle.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(
                            label: Text(status),
                            backgroundColor: status.toLowerCase().contains('pagado') || status.toLowerCase().contains('paid')
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Documentos y Declaraciones:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      documents.isEmpty
                          ? const Text(
                        'No hay documentos adjuntos para este mes.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: documents.length,
                        itemBuilder: (context, docIndex) {
                          var doc = documents[docIndex];
                          String docTitle = doc['title'] ?? 'Documento';
                          String docUrl = doc['fileUrl'] ?? '';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                            title: Text(
                              docTitle,
                              style: const TextStyle(decoration: TextDecoration.underline),
                            ),
                            onTap: () => _openFile(docUrl),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => _uploadDocument(recordId),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir Archivo a este Mes'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}