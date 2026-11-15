import 'dart:convert' as convert;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/download_helper.dart';
import '../../models/client_model.dart';
import 'edit_client_screen.dart';

class FolderNode {
  String name;
  Map<String, FolderNode> subFolders = {};
  List<Map<String, dynamic>> documents = [];

  FolderNode({required this.name});
}

class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  bool _isUploading = false;
  String _selectedMonthFilter = 'TODOS';

  bool isProtectedPath(String folderPath) {
    String upper = folderPath.toUpperCase().trim();
    if (upper.contains('LEGALES') ||
        upper.contains('DOCUMENTACION LEGAL') ||
        upper.contains('DOCUMENTACIÓN LEGAL')) {
      return true;
    }
    return false;
  }

  final List<String> _commonMainFolders = const [
    'LEGALES',
    'DOCUMENTACION LEGAL',
    'ALCALDÍA',
    'DPP',
    'PARAFISCALES',
    'SENIAT',
    'SACS',
    '+ Nueva Carpeta Personalizada',
  ];

  final List<String> _months = const [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  Future<void> _uploadDocument() async {
    String selectedMain = _commonMainFolders[0];
    String selectedMonth = _months[DateTime.now().month - 1];
    final TextEditingController customMainController = TextEditingController();
    final TextEditingController subFolderController = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Organizar Documento en Carpeta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMain,
                      isExpanded: true,
                      items: _commonMainFolders.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedMain = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Carpeta Principal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (selectedMain == '+ Nueva Carpeta Personalizada') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: customMainController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la Nueva Carpeta',
                          hintText: 'Ej. AUDITORÍA, LEGALES, BALANCES...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: subFolderController,
                      decoration: const InputDecoration(
                        labelText: 'Subcarpeta (Opcional)',
                        hintText: 'Ej. DECLARACIONES, SEGURO SOCIAL, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMonth,
                      isExpanded: true,
                      items: _months.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(m, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedMonth = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Mes del Documento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedMain == '+ Nueva Carpeta Personalizada' &&
                        customMainController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Escribe el nombre de la carpeta personalizada')),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Continuar y Subir'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    String mainFolder = selectedMain == '+ Nueva Carpeta Personalizada'
        ? customMainController.text.toUpperCase().trim()
        : selectedMain.toUpperCase().trim();
    String subFolder = subFolderController.text.toUpperCase().trim();

    String folderPath = subFolder.isNotEmpty ? '$mainFolder/$subFolder' : mainFolder;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
        withData: true,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      // Guardar la estructura de carpetas en el cliente de forma permanente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.client.clientId)
          .set({
        'folderPaths': FieldValue.arrayUnion(['ALCALDÍA', 'DPP', 'PARAFISCALES', 'SENIAT', folderPath]),
      }, SetOptions(merge: true));

      int currentYear = DateTime.now().year;
      int monthIndex = _months.indexOf(selectedMonth) + 1;
      String periodText = '$selectedMonth $currentYear';

      for (var file in result.files) {
        if (file.bytes != null) {
          Uint8List fileBytes = file.bytes!;
          String fileName = file.name;
          String base64File = convert.base64Encode(fileBytes);

          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.client.clientId)
              .collection('documents')
              .add({
            'title': fileName,
            'folderPath': folderPath,
            'category': folderPath,
            'period': periodText,
            'month': selectedMonth,
            'monthIndex': monthIndex,
            'year': currentYear,
            'fileBase64': base64File,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Documentos del mes de $selectedMonth guardados con éxito!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el archivo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadDocumentToPath(String targetPath) async {
    String upperTargetPath = targetPath.toUpperCase().trim();
    String selectedMonth = _months[DateTime.now().month - 1];

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Subir Archivo a "$upperTargetPath"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMonth,
                    isExpanded: true,
                    items: _months.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() => selectedMonth = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Mes del Documento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Seleccionar Archivos'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
        withData: true,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      // Guardar la estructura de carpetas en el cliente de forma permanente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.client.clientId)
          .set({
        'folderPaths': FieldValue.arrayUnion(['ALCALDÍA', 'DPP', 'PARAFISCALES', 'SENIAT', upperTargetPath]),
      }, SetOptions(merge: true));

      int currentYear = DateTime.now().year;
      int monthIndex = _months.indexOf(selectedMonth) + 1;
      String periodText = '$selectedMonth $currentYear';

      for (var file in result.files) {
        if (file.bytes != null) {
          Uint8List fileBytes = file.bytes!;
          String fileName = file.name;
          String base64File = convert.base64Encode(fileBytes);

          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.client.clientId)
              .collection('documents')
              .add({
            'title': fileName,
            'folderPath': upperTargetPath,
            'category': upperTargetPath,
            'period': periodText,
            'month': selectedMonth,
            'monthIndex': monthIndex,
            'year': currentYear,
            'fileBase64': base64File,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Documentos del mes de $selectedMonth agregados a "$upperTargetPath"!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar archivos: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _createSubFolderDialog(String parentPath) async {
    final TextEditingController nameController = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Crear Subcarpeta en "$parentPath"'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Subcarpeta',
              hintText: 'Ej. IVSS, FAOV, PAGOS, DECLARACIONES...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Crear Carpeta'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      String subName = nameController.text.toUpperCase().trim();
      String newFolderPath = parentPath.isEmpty ? subName : '$parentPath/$subName';

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .set({
          'folderPaths': FieldValue.arrayUnion([newFolderPath]),
        }, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Subcarpeta "$newFolderPath" creada con éxito!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear subcarpeta: $e')),
        );
      }
    }
  }

  Future<void> _renameFolderDialog(String currentPath, String oldFolderName) async {
    TextEditingController nameController = TextEditingController(text: oldFolderName);

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar / Renombrar Carpeta'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nuevo Nombre de la Carpeta',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      String newFolderName = nameController.text.toUpperCase().trim();
      if (newFolderName == oldFolderName.toUpperCase().trim()) return;

      List<String> pathParts = currentPath.split('/');
      pathParts[pathParts.length - 1] = newFolderName;
      String newPath = pathParts.join('/');

      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .get();

        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        List<dynamic> storedFolderPaths = List.from(data?['folderPaths'] ?? []);

        List<dynamic> updatedPaths = [];
        for (var p in storedFolderPaths) {
          String pStr = p.toString().toUpperCase().trim();
          if (pStr == currentPath) {
            updatedPaths.add(newPath);
          } else if (pStr.startsWith('$currentPath/')) {
            updatedPaths.add(pStr.replaceFirst(currentPath, newPath));
          } else {
            updatedPaths.add(pStr);
          }
        }
        if (!updatedPaths.contains(newPath)) {
          updatedPaths.add(newPath);
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .set({'folderPaths': updatedPaths}, SetOptions(merge: true));

        var docs = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .collection('documents')
            .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in docs.docs) {
          String docPath = (doc.data()['folderPath'] ?? doc.data()['category'] ?? '').toString().toUpperCase().trim();
          if (docPath == currentPath) {
            batch.update(doc.reference, {'folderPath': newPath});
          } else if (docPath.startsWith('$currentPath/')) {
            batch.update(doc.reference, {'folderPath': docPath.replaceFirst(currentPath, newPath)});
          }
        }
        await batch.commit();

        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Carpeta renombrada a "$newFolderName" correctamente!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al renombrar carpeta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFolderDialog(String currentPath, String folderName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Carpeta "$folderName"'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la carpeta "$folderName"?\n\n'
          'Se eliminará esta carpeta y todos los archivos dentro de ella.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar Carpeta'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .get();

        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        List<dynamic> storedFolderPaths = List.from(data?['folderPaths'] ?? []);

        List<dynamic> updatedPaths = storedFolderPaths.where((p) {
          String pStr = p.toString().toUpperCase().trim();
          return pStr != currentPath && !pStr.startsWith('$currentPath/');
        }).toList();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .set({'folderPaths': updatedPaths}, SetOptions(merge: true));

        var docs = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .collection('documents')
            .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in docs.docs) {
          String docPath = (doc.data()['folderPath'] ?? doc.data()['category'] ?? '').toString().toUpperCase().trim();
          if (docPath == currentPath || docPath.startsWith('$currentPath/')) {
            batch.delete(doc.reference);
          }
        }
        await batch.commit();

        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Carpeta "$folderName" eliminada correctamente!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar carpeta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearAllDocuments() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Documentos del Mes Anterior'),
        content: const Text(
          '¿Deseas vaciar los documentos para iniciar el nuevo mes?\n\n'
          'Se vaciarán únicamente los documentos de las carpetas mensuales para dar paso al nuevo mes. Se CONSERVARÁN intactos todos los documentos de la carpeta LEGALES y toda la estructura de carpetas y subcarpetas permanecerá fija e intacta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar Archivos'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        var docs = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .collection('documents')
            .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        int count = 0;
        for (var doc in docs.docs) {
          String folderPath = (doc.data()['folderPath'] ?? doc.data()['category'] ?? '').toString();
          if (!isProtectedPath(folderPath)) {
            batch.delete(doc.reference);
            count++;
          }
        }
        if (count > 0) {
          await batch.commit();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Documentos mensuales vaciados con éxito! La estructura de carpetas y los documentos protegidos se mantuvieron intactos.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vaciar documentos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _autoClean3MonthsRollingDocuments(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> monthGroups = {};

    const Map<String, int> monthMap = {
      'ENERO': 1, 'FEBRERO': 2, 'MARZO': 3, 'ABRIL': 4,
      'MAYO': 5, 'JUNIO': 6, 'JULIO': 7, 'AGOSTO': 8,
      'SEPTIEMBRE': 9, 'OCTUBRE': 10, 'NOVIEMBRE': 11, 'DICIEMBRE': 12
    };

    for (var doc in docs) {
      var data = doc.data();
      String folderPath = (data['folderPath'] ?? data['category'] ?? '').toString();

      // OMITIR carpetas y subcarpetas protegidas (NUNCA se borran)
      if (isProtectedPath(folderPath)) continue;

      int? docMonth = data['monthIndex'] as int?;
      int? docYear = data['year'] as int?;
      Timestamp? createdAt = data['createdAt'] as Timestamp?;

      if (docMonth == null || docYear == null) {
        String periodStr = (data['period'] ?? '').toString().toUpperCase().trim();
        for (var entry in monthMap.entries) {
          if (periodStr.contains(entry.key)) {
            docMonth ??= entry.value;
            break;
          }
        }
        RegExp yearReg = RegExp(r'\b(20\d{2})\b');
        Match? match = yearReg.firstMatch(periodStr);
        if (match != null) {
          docYear ??= int.tryParse(match.group(1)!);
        }
      }

      int year = docYear ?? (createdAt != null ? createdAt.toDate().year : DateTime.now().year);
      int month = docMonth ?? (createdAt != null ? createdAt.toDate().month : DateTime.now().month);

      String periodKey = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      monthGroups.putIfAbsent(periodKey, () => []).add(doc);
    }

    // Si hay más de 3 meses registrados en las carpetas mensuales, eliminar los meses antiguos dejando solo los 3 más recientes
    List<String> sortedPeriods = monthGroups.keys.toList()..sort();

    if (sortedPeriods.length > 3) {
      List<String> oldPeriodsToDelete = sortedPeriods.sublist(0, sortedPeriods.length - 3);
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (String oldPeriod in oldPeriodsToDelete) {
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docsToDelete = monthGroups[oldPeriod] ?? [];
          for (var doc in docsToDelete) {
            batch.delete(doc.reference);
          }
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Error al purgar meses antiguos: $e');
      }
    }
  }

  Future<void> _openBase64File(String base64String, String fileName) async {
    try {
      await downloadFile(
        fileName: fileName,
        base64String: base64String,
        fileUrl: '',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el archivo: $e')),
      );
    }
  }

  Future<void> _deleteDocument(String docId, String docTitle) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Documento'),
        content: Text('¿Estás seguro de que deseas eliminar "$docTitle"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .collection('documents')
            .doc(docId)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento eliminado correctamente')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editDocument(String docId, String currentTitle, String currentPath) async {
    final TextEditingController titleController = TextEditingController(text: currentTitle);
    final TextEditingController pathController = TextEditingController(text: currentPath);

    bool? updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Corregir / Editar Documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título del Documento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'Ruta de Carpetas (ej. Parafiscales/Seguro Social)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El título no puede estar vacío')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        );
      },
    );

    if (updated == true) {
      String newPath = pathController.text.trim();
      if (newPath.isEmpty) newPath = 'General';

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.client.clientId)
            .collection('documents')
            .doc(docId)
            .update({
          'title': titleController.text.trim(),
          'folderPath': newPath,
          'category': newPath,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Documento corregido con éxito!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  FolderNode _buildFolderTree(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, [
    List<dynamic>? storedFolderPaths,
    String selectedMonthFilter = 'TODOS',
  ]) {
    FolderNode root = FolderNode(name: 'Root');

    Set<String> allFolderPaths = {
      'LEGALES',
      'DOCUMENTACION LEGAL',
      'ALCALDÍA',
      'ALCALDÍA/SADTC',
      'ALCALDÍA/SADTC/RENOVACION ANUAL',
      'ALCALDÍA/SIGAT',
      'ALCALDÍA/SIGAT/PERMISO PUBLICIDAD',
      'DPP',
      'PARAFISCALES',
      'PARAFISCALES/IVSS',
      'PARAFISCALES/FAOV',
      'PARAFISCALES/INCES',
      'SENIAT',
      'SENIAT/IVA',
      'SENIAT/ISLR',
      'SENIAT/RETENCIONES',
      'SACS',
      'SACS/PERMISO SANITARIO',
      'SACS/CERTIFICADO DE SALUD',
      'SACS/MANIPULACION DE ALIMENTOS',
    };
    if (storedFolderPaths != null) {
      for (var p in storedFolderPaths) {
        if (p != null && p.toString().trim().isNotEmpty) {
          allFolderPaths.add(p.toString().toUpperCase().trim());
        }
      }
    }

    // Inicializar todas las carpetas y subcarpetas conocidas para preservar la estructura completa en MAYÚSCULAS
    for (String path in allFolderPaths) {
      List<String> parts = path.split('/').map((p) => p.trim().toUpperCase()).where((p) => p.isNotEmpty).toList();
      FolderNode currentNode = root;
      for (String part in parts) {
        if (!currentNode.subFolders.containsKey(part)) {
          currentNode.subFolders[part] = FolderNode(name: part);
        }
        currentNode = currentNode.subFolders[part]!;
      }
    }

    // Agregar documentos en sus respectivas carpetas y subcarpetas
    for (var doc in docs) {
      var data = doc.data();
      String period = (data['period'] ?? '').toString().trim();

      // Si se selecciona un mes específico en el filtro, omitir documentos de otros meses
      if (selectedMonthFilter != 'TODOS' && period != selectedMonthFilter) {
        continue;
      }

      String rawPath = data['folderPath'] ?? data['category'] ?? 'GENERAL';
      List<String> parts = rawPath.split('/').map((p) => p.trim().toUpperCase()).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) parts = ['GENERAL'];

      FolderNode currentNode = root;
      for (String part in parts) {
        if (!currentNode.subFolders.containsKey(part)) {
          currentNode.subFolders[part] = FolderNode(name: part);
        }
        currentNode = currentNode.subFolders[part]!;
      }
      String title = data['title'] ?? data['nombre_archivo'] ?? data['nombre'] ?? 'Documento';
      String fileBase64 = data['fileBase64'] ?? data['archivo_base64'] ?? data['base64'] ?? '';
      String fileUrl = data['fileUrl'] ?? data['url'] ?? data['downloadUrl'] ?? '';

      currentNode.documents.add({
        'id': doc.id,
        'title': title,
        'period': period,
        'fileBase64': fileBase64,
        'fileUrl': fileUrl,
        'folderPath': rawPath.toUpperCase(),
      });
    }
    return root;
  }

  Widget _buildMonthFilterDropdown(List<String> availableMonths) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Colors.indigo, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Ver Mes:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableMonths.contains(_selectedMonthFilter) ? _selectedMonthFilter : 'TODOS',
                isExpanded: true,
                items: availableMonths.map((m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Text(
                      m == 'TODOS' ? 'Todos los Meses (Máx. 3 meses)' : m,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonthFilter = value;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderWidget(FolderNode node, bool isMobile, [String parentPath = '']) {
    var sortedSubFolders = node.subFolders.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Column(
      children: sortedSubFolders.map((entry) {
        String folderName = entry.key;
        FolderNode subNode = entry.value;
        String currentPath = parentPath.isEmpty ? folderName : '$parentPath/$folderName';

        bool hasSubFolders = subNode.subFolders.isNotEmpty;

        var sortedDocs = List<Map<String, dynamic>>.from(subNode.documents)
          ..sort((a, b) => (a['title'] as String).toLowerCase().compareTo((b['title'] as String).toLowerCase()));

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: Icon(hasSubFolders ? Icons.folder : Icons.folder_open, color: Colors.indigo, size: 28),
            title: Text(
              folderName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16, color: Colors.indigo),
            ),
            subtitle: Text(
              '${subNode.subFolders.length} subcarpeta(s), ${subNode.documents.length} archivo(s)',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.create_new_folder, color: Colors.indigo, size: 22),
                  tooltip: 'Crear subcarpeta dentro de "$folderName"',
                  onPressed: () => _createSubFolderDialog(currentPath),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 22),
                  tooltip: 'Agregar archivo a "$folderName"',
                  onPressed: () => _uploadDocumentToPath(currentPath),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 22, color: Colors.indigo),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _renameFolderDialog(currentPath, folderName);
                    } else if (value == 'delete') {
                      _deleteFolderDialog(currentPath, folderName);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text('Renombrar Carpeta'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar Carpeta', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            initiallyExpanded: true,
            children: [
              if (hasSubFolders)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                  child: _buildFolderWidget(subNode, isMobile, currentPath),
                ),
              ...sortedDocs.map((docItem) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                    title: Text(
                      docItem['title'],
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(docItem['period'], style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: docItem['fileBase64'].isNotEmpty
                              ? () => _openBase64File(docItem['fileBase64'], docItem['title'])
                              : null,
                          icon: const Icon(Icons.download, size: 13),
                          label: const Text('Descargar', style: TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                          tooltip: 'Corregir / Editar documento',
                          onPressed: () => _editDocument(docItem['id'], docItem['title'], docItem['folderPath']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          tooltip: 'Eliminar documento',
                          onPressed: () => _deleteDocument(docItem['id'], docItem['title']),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.client.clientId).snapshots(),
      builder: (context, snapshot) {
        var data = snapshot.data?.data();
        String businessName = data?['businessName'] ?? widget.client.businessName;
        String taxId = data?['taxId'] ?? widget.client.taxId;
        String email = data?['email'] ?? widget.client.email;
        String? logoBase64 = data?['logoBase64'] ?? widget.client.logoBase64;
        double pendingTax = (data?['pendingTaxAmount'] ?? widget.client.pendingTaxAmount).toDouble();

        ClientModel currentClient = ClientModel(
          clientId: widget.client.clientId,
          businessName: businessName,
          email: email,
          taxId: taxId,
          accountantId: widget.client.accountantId,
          logoBase64: logoBase64,
          pendingTaxAmount: pendingTax,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(businessName, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Editar Datos del Cliente',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditClientScreen(client: currentClient),
                    ),
                  );
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 650;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarjeta de cabecera adaptativa
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: isMobile ? 55 : 75,
                                      height: isMobile ? 55 : 75,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(10),
                                        image: logoBase64 != null
                                            ? DecorationImage(
                                          image: MemoryImage(convert.base64Decode(logoBase64)),
                                          fit: BoxFit.cover,
                                        )
                                            : null,
                                      ),
                                      child: logoBase64 == null
                                          ? Icon(Icons.business, size: isMobile ? 28 : 38, color: Colors.grey)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            businessName,
                                            style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text('RIF: $taxId', style: TextStyle(color: Colors.grey.shade700, fontSize: isMobile ? 12 : 14)),
                                          const SizedBox(height: 2),
                                          Text('Correo: $email', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 11 : 13), overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Impuestos por Pagar:',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber),
                                      ),
                                      Text(
                                        '\$${pendingTax.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sección de título y botones responsivos
                        isMobile
                            ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Portal y Tributos',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _uploadDocument,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: _isUploading
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                                  : const Icon(Icons.upload_file),
                              label: Text(_isUploading ? 'Guardando...' : 'Subir Documento'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _clearAllDocuments,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.delete_sweep),
                              label: const Text('Vaciar Mes Anterior'),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Portal y Tributos del Cliente',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _clearAllDocuments,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  icon: const Icon(Icons.delete_sweep),
                                  label: const Text('Vaciar Mes Anterior'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _isUploading ? null : _uploadDocument,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: _isUploading
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                      : const Icon(Icons.upload_file),
                                  label: Text(_isUploading ? 'Guardando...' : 'Subir Documento'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Listado dinámico por árbol de carpetas y subcarpetas recursivas
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.client.clientId)
                              .collection('documents')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, docSnapshot) {
                            if (docSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
                            }

                            var documents = docSnapshot.data?.docs ?? [];

                            if (documents.isNotEmpty) {
                              _autoClean3MonthsRollingDocuments(documents);
                            }

                            // Obtener lista de meses disponibles para el filtro (máximo 3 meses más recientes)
                            Set<String> periodsSet = {};
                            for (var doc in documents) {
                              var docData = doc.data();
                              String period = (docData['period'] ?? '').toString().trim();
                              if (period.isNotEmpty) {
                                periodsSet.add(period);
                              }
                            }
                            List<String> sortedPeriods = periodsSet.toList()..sort();
                            if (sortedPeriods.length > 3) {
                              sortedPeriods = sortedPeriods.sublist(sortedPeriods.length - 3);
                            }
                            List<String> availableFilterMonths = ['TODOS', ...sortedPeriods];

                            List<dynamic>? storedFolderPaths = data?['folderPaths'] as List<dynamic>?;
                            FolderNode rootNode = _buildFolderTree(documents, storedFolderPaths, _selectedMonthFilter);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (availableFilterMonths.length > 1)
                                  _buildMonthFilterDropdown(availableFilterMonths),
                                _buildFolderWidget(rootNode, isMobile),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
