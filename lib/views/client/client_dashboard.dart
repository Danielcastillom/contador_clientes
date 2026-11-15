import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/download_helper.dart';
import '../auth/login_view.dart';

class FolderNode {
  String name;
  Map<String, FolderNode> subFolders = {};
  List<Map<String, dynamic>> documents = [];

  FolderNode({required this.name});
}

class ClientDashboard extends StatefulWidget {
  final String clientId; // El ID del cliente que ha iniciado sesión
  final String accountantId; // El ID del contador asignado

  const ClientDashboard({super.key, required this.clientId, required this.accountantId});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
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
        debugPrint('Error al purgar mes antiguo en portal de cliente: $e');
      }
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _fetchAccountantProfile() async {
    if (widget.accountantId.isEmpty) return null;
    var doc = await FirebaseFirestore.instance.collection('accountant_profile').doc(widget.accountantId).get();
    if (doc.exists) return doc;

    var query = await FirebaseFirestore.instance
        .collection('accountant_profile')
        .where('email', isEqualTo: widget.accountantId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first;
    }
    return null;
  }

  Future<void> _openDocument(BuildContext context, Map<String, dynamic> docItem) async {
    try {
      String title = docItem['title'] ?? 'documento';
      String fileUrl = docItem['fileUrl'] ?? '';
      String base64String = docItem['fileBase64'] ?? '';

      if (fileUrl.isEmpty && base64String.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo no contiene información válida.')),
        );
        return;
      }

      await downloadFile(
        fileName: title,
        base64String: base64String,
        fileUrl: fileUrl,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar el archivo: $e')),
      );
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

    // Inicializar carpetas base y subcarpetas para mantener la estructura intacta en MAYÚSCULAS
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

  Widget _buildFolderWidget(BuildContext context, FolderNode node, bool isMobile, [String parentPath = '']) {
    var sortedSubFolders = node.subFolders.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Column(
      mainAxisSize: MainAxisSize.min,
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
            initiallyExpanded: true,
            children: [
              if (hasSubFolders)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                  child: _buildFolderWidget(context, subNode, isMobile, currentPath),
                ),
              ...sortedDocs.map((docItem) {
                bool hasFile = (docItem['fileBase64'] as String).isNotEmpty || (docItem['fileUrl'] as String).isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                    title: Text(
                      docItem['title'],
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(docItem['period'], style: const TextStyle(fontSize: 11)),
                    trailing: ElevatedButton.icon(
                      onPressed: hasFile ? () => _openDocument(context, docItem) : null,
                      icon: const Icon(Icons.download, size: 12),
                      label: const Text('Descargar', style: TextStyle(fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Portal y Documentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginView()),
                (route) => false,
              );
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.clientId).snapshots(),
        builder: (context, userSnapshot) {
          var userData = userSnapshot.data?.data();
          List<dynamic>? storedFolderPaths = userData?['folderPaths'] as List<dynamic>?;

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: _fetchAccountantProfile(),
            builder: (context, accountantSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.clientId)
                    .collection('documents')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, docSnapshot) {
                  if (docSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var documents = docSnapshot.data?.docs ?? [];

                  if (documents.isNotEmpty) {
                    _autoClean3MonthsRollingDocuments(documents);
                  }

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

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWide = constraints.maxWidth > 850;

                      FolderNode rootNode = _buildFolderTree(documents, storedFolderPaths, _selectedMonthFilter);

                      Widget documentsView = Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (availableFilterMonths.length > 1)
                              _buildMonthFilterDropdown(availableFilterMonths),
                            _buildFolderWidget(context, rootNode, constraints.maxWidth < 650),
                          ],
                        ),
                      );

                      Widget accountantCard = _buildAccountantCard(accountantSnapshot);

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 320,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: accountantCard,
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: documentsView,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              accountantCard,
                              const SizedBox(height: 16),
                              documentsView,
                            ],
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAccountantCard(AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>?> accountantSnapshot) {
    if (!accountantSnapshot.hasData || accountantSnapshot.data == null || !accountantSnapshot.data!.exists) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Información del contador no disponible.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final data = accountantSnapshot.data!.data()!;
    final companyName = data['companyName'] ?? 'Estudio Contable';
    final rif = data['rif'] ?? '';
    final phone = data['phone'] ?? '';
    final address = data['address'] ?? '';
    final logoBase64 = data['logoBase64'];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: logoBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Image.memory(
                          convert.base64Decode(logoBase64),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    )
                  : const Icon(Icons.business, size: 40, color: Colors.indigo),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu Contador / Estudio',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              companyName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 4),
            if (rif.isNotEmpty)
              Text(
                'RIF: $rif',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            const Divider(height: 24),
            if (phone.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(phone, style: const TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (address.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(address, style: const TextStyle(fontSize: 13, color: Colors.black54))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
