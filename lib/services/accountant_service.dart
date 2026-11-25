import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AccountantService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene los datos del perfil del contador usando su email o UID
  static Future<Map<String, dynamic>?> getAccountantProfile(String? identifier) async {
    try {
      if (identifier != null && identifier.trim().isNotEmpty) {
        final id = identifier.trim();

        // 1. Buscar directamente por ID de documento (sea Email o UID)
        var doc = await _firestore.collection('accountant_profile').doc(id).get();
        if (doc.exists && doc.data() != null && doc.data()!.isNotEmpty) {
          return doc.data();
        }

        // 2. Buscar por campo 'email'
        var qEmail = await _firestore
            .collection('accountant_profile')
            .where('email', isEqualTo: id)
            .limit(1)
            .get();
        if (qEmail.docs.isNotEmpty) {
          return qEmail.docs.first.data();
        }

        // 3. Buscar por campo 'accountantEmail'
        var qAccEmail = await _firestore
            .collection('accountant_profile')
            .where('accountantEmail', isEqualTo: id)
            .limit(1)
            .get();
        if (qAccEmail.docs.isNotEmpty) {
          return qAccEmail.docs.first.data();
        }

        // 4. Buscar si en la colección 'users' existe este correo y tiene UID asociado
        var userDocs = await _firestore
            .collection('users')
            .where('email', isEqualTo: id)
            .limit(1)
            .get();
        if (userDocs.docs.isNotEmpty) {
          String uidFromDoc = userDocs.docs.first.id;
          var docByUid = await _firestore.collection('accountant_profile').doc(uidFromDoc).get();
          if (docByUid.exists && docByUid.data() != null) {
            return docByUid.data();
          }
        }
      }

      // 5. Como respaldo absoluto, si hay documentos en accountant_profile, devolver el primero disponible
      var allDocs = await _firestore.collection('accountant_profile').get();
      if (allDocs.docs.isNotEmpty) {
        return allDocs.docs.first.data();
      }
    } catch (e) {
      debugPrint('Error en getAccountantProfile: $e');
    }
    return null;
  }

  /// Guarda el perfil del contador sincronizando tanto por UID como por Email
  static Future<void> saveAccountantProfile({
    required String uid,
    required String email,
    required String companyName,
    required String rif,
    required String phone,
    required String address,
    String? logoBase64,
  }) async {
    Map<String, dynamic> profileData = {
      'companyName': companyName.trim(),
      'rif': rif.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'logoBase64': logoBase64,
      'email': email.trim(),
      'accountantEmail': email.trim(),
      'uid': uid.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (uid.isNotEmpty) {
      await _firestore
          .collection('accountant_profile')
          .doc(uid)
          .set(profileData, SetOptions(merge: true));
    }

    if (email.isNotEmpty) {
      await _firestore
          .collection('accountant_profile')
          .doc(email.trim())
          .set(profileData, SetOptions(merge: true));
    }
  }

  /// Sincroniza automáticamente los datos si ya fueron guardados bajo UID pero aún no bajo Email
  static Future<void> autoSyncCurrentAccountant() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final uid = user.uid;
      final email = user.email?.trim() ?? '';

      DocumentSnapshot<Map<String, dynamic>>? sourceDoc;

      var docUid = await _firestore.collection('accountant_profile').doc(uid).get();
      if (docUid.exists && docUid.data() != null) {
        sourceDoc = docUid;
      } else if (email.isNotEmpty) {
        var docEmail = await _firestore.collection('accountant_profile').doc(email).get();
        if (docEmail.exists && docEmail.data() != null) {
          sourceDoc = docEmail;
        }
      }

      if (sourceDoc != null && sourceDoc.data() != null) {
        var data = Map<String, dynamic>.from(sourceDoc.data()!);
        data['email'] = email;
        data['accountantEmail'] = email;
        data['uid'] = uid;

        if (email.isNotEmpty) {
          await _firestore
              .collection('accountant_profile')
              .doc(email)
              .set(data, SetOptions(merge: true));
        }
        await _firestore
            .collection('accountant_profile')
            .doc(uid)
            .set(data, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error en autoSyncCurrentAccountant: $e');
    }
  }
}
