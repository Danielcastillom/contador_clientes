import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../views/client/client_dashboard.dart';
import '../views/accountant/accountant_dashboard.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Función para redirigir según el rol del usuario en la colección 'users' y config/admins
  Future<void> handleUserLoginRedirect(BuildContext context, User user) async {
    try {
      print('🔍 [DEBUG] Verificando rol para el UID: ${user.uid}');
      String email = user.email ?? '';

      bool isAccountant = email == 'castillo8505@gmail.com';

      if (!isAccountant) {
        // 1. Verificar por UID en users
        try {
          var userDoc = await _db.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            if (data?['role'] == 'accountant') {
              isAccountant = true;
            }
          }
        } catch (e) {
          print('Error al verificar users: $e');
        }

        // 2. Verificar en accountant_profile
        if (!isAccountant) {
          try {
            var profileDoc = await _db.collection('accountant_profile').doc(user.uid).get();
            if (profileDoc.exists) {
              isAccountant = true;
            } else {
              var query = await _db.collection('accountant_profile').where('email', isEqualTo: email).get();
              if (query.docs.isNotEmpty) isAccountant = true;
            }
          } catch (e) {
            print('Error al verificar accountant_profile: $e');
          }
        }

        // 3. Verificar en config/admins (Array de correos de administradores)
        if (!isAccountant) {
          try {
            var adminConfigDoc = await _db.collection('config').doc('admins').get();
            if (adminConfigDoc.exists) {
              List<dynamic> adminEmails = adminConfigDoc.data()?['emails'] ?? [];
              for (var adminEmail in adminEmails) {
                if (adminEmail.toString().trim().toLowerCase() == email.trim().toLowerCase()) {
                  isAccountant = true;
                  break;
                }
              }
            }
          } catch (e) {
            print('Error al verificar config/admins: $e');
          }
        }
      }

      print('👤 [DEBUG] Es contador / admin: $isAccountant');

      if (isAccountant) {
        // Redirigir al panel del contador
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AccountantDashboard()),
        );
      } else {
        // Redirigir al panel del cliente (pasando su UID y accountantId)
        DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();
        final clientData = userDoc.exists ? userDoc.data() as Map<String, dynamic>? : null;
        final accountantId = clientData?['accountantId'] ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ClientDashboard(clientId: user.uid, accountantId: accountantId)),
        );
      }
    } catch (e) {
      print('❌ [DEBUG] Error al redirigir según el rol: $e');
    }
  }
}
