import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_dashboard.dart';
import '../auth/login_view.dart';

class ClientPortalView extends StatelessWidget {
  const ClientPortalView({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findClientDoc(User user) async {
    try {
      // 1. Buscar primero en la colección 'users' por UID del documento
      var docByUid = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docByUid.exists) {
        return docByUid;
      }

      // 2. Buscar en la colección 'users' por correo electrónico
      if (user.email != null && user.email!.isNotEmpty) {
        var queryUsers = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (queryUsers.docs.isNotEmpty) {
          return queryUsers.docs.first;
        }
      }

      // 3. Fallback: Buscar en la colección 'clients' por correo electrónico
      if (user.email != null && user.email!.isNotEmpty) {
        var queryClients = await FirebaseFirestore.instance
            .collection('clients')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (queryClients.docs.isNotEmpty) {
          return queryClients.docs.first;
        }
      }
    } catch (e) {
      print('Error al buscar documento de cliente: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No hay sesión activa.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginView()),
                  );
                },
                child: const Text('Iniciar Sesión'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _findClientDoc(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error al cargar perfil: ${snapshot.error}'),
            ),
          );
        }

        final doc = snapshot.data;
        if (doc == null || !doc.exists) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Portal de Cliente'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginView()),
                    );
                  },
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      'No se encontró un perfil de cliente asociado al correo: ${user.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginView()),
                        );
                      },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final clientId = doc.id;
        final data = doc.data() ?? {};
        final accountantId = data['accountantId'] ?? '';
        return ClientDashboard(clientId: clientId, accountantId: accountantId);
      },
    );
  }
}
