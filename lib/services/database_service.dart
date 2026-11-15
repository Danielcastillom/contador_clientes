import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/client_model.dart';
import '../models/monthly_record_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Obtener clientes asignados a un contador
  Stream<List<ClientModel>> getClientsByAccountant(String accountantId) {
    return _db
        .collection('clients')
        .where('accountantId', isEqualTo: accountantId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ClientModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Obtener registros mensuales y ordenarlos localmente por año y mes descendentemente
  Stream<List<MonthlyRecordModel>> getMonthlyRecords(String clientId) {
    print('🔍 [DEBUG] Buscando registros para el cliente ID: $clientId');
    return _db
        .collection('clients')
        .doc(clientId)
        .collection('monthly_records')
        .snapshots()
        .map((snapshot) {
      print('📦 [DEBUG] Documentos encontrados: ${snapshot.docs.length}');
      final records = snapshot.docs
          .map((doc) => MonthlyRecordModel.fromMap(doc.data(), doc.id))
          .toList();

      // Ordenamiento local descendentemente por año y mes
      records.sort((a, b) {
        int yearCompare = b.year.compareTo(a.year);
        if (yearCompare != 0) return yearCompare;
        return b.month.compareTo(a.month);
      });

      return records;
    });
  }

  // Guardar o actualizar registro mensual
  Future<void> saveMonthlyRecord({
    required String clientId,
    required String recordId,
    required int year,
    required int month,
    required double totalIncome,
    required double totalExpenses,
    required double taxPayable,
    required String status,
  }) async {
    await _db
        .collection('clients')
        .doc(clientId)
        .collection('monthly_records')
        .doc(recordId)
        .set({
      'year': year,
      'month': month,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'taxPayable': taxPayable,
      'status': status,
    }, SetOptions(merge: true));
  }

  // Subir documento adjunto al registro mensual
  Future<void> uploadDocument({
    required String clientId,
    required String recordId,
    required File file,
    required String fileName,
  }) async {
    Reference ref = _storage.ref().child('clients/$clientId/$recordId/$fileName');
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();

    await _db
        .collection('clients')
        .doc(clientId)
        .collection('monthly_records')
        .doc(recordId)
        .update({
      'documents': FieldValue.arrayUnion([
        {
          'title': fileName,
          'fileUrl': downloadUrl,
          'uploadedAt': Timestamp.now(),
        }
      ])
    });
  }

  // Crear / Cargar Cliente Santa Bárbara en la app
  Future<String> seedSantaBarbaraClient(String accountantEmail) async {
    const String clientId = 'cliente_santa_barbara';
    final Map<String, dynamic> clientData = {
      'businessName': 'Comercializadora Santa Bárbara C.A.',
      'email': 'santabarbara@ejemplo.com',
      'taxId': 'J-40192837-4',
      'pendingTaxAmount': 1250.50,
      'role': 'client',
      'accountantId': accountantEmail.isEmpty ? 'contador@ejemplo.com' : accountantEmail,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(clientId).set(clientData, SetOptions(merge: true));
    await _db.collection('clients').doc(clientId).set(clientData, SetOptions(merge: true));

    final List<Map<String, dynamic>> records = [
      {
        'id': '2026_02',
        'year': 2026,
        'month': 2,
        'totalIncome': 12500.00,
        'totalExpenses': 4300.00,
        'taxPayable': 650.00,
        'status': 'Pendiente',
      },
      {
        'id': '2026_01',
        'year': 2026,
        'month': 1,
        'totalIncome': 15800.00,
        'totalExpenses': 5200.00,
        'taxPayable': 850.50,
        'status': 'Declarado',
      },
      {
        'id': '2025_12',
        'year': 2025,
        'month': 12,
        'totalIncome': 18900.00,
        'totalExpenses': 6100.00,
        'taxPayable': 1100.00,
        'status': 'Pagado',
      },
    ];

    for (var rec in records) {
      await _db
          .collection('clients')
          .doc(clientId)
          .collection('monthly_records')
          .doc(rec['id'])
          .set({
        'year': rec['year'],
        'month': rec['month'],
        'totalIncome': rec['totalIncome'],
        'totalExpenses': rec['totalExpenses'],
        'taxPayable': rec['taxPayable'],
        'status': rec['status'],
      }, SetOptions(merge: true));
    }

    return clientId;
  }
}