import 'dart:convert' as convert;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/client_model.dart';
import '../../utils/image_helper.dart';
import 'client_detail_screen.dart';
import 'add_client_dialog.dart';
import 'edit_client_screen.dart';
import 'accountant_profile_screen.dart';
import '../auth/login_view.dart';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String accountantId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getAccountantProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = (user?.email ?? 'masexactoa.i@gmail.com').toLowerCase().trim();

      if (accountantId.isNotEmpty) {
        var doc = await FirebaseFirestore.instance.collection('accountant_profile').doc(accountantId).get();
        if (doc.exists) return doc;
      }

      if (email.isNotEmpty) {
        var docEmail = await FirebaseFirestore.instance.collection('accountant_profile').doc(email).get();
        if (docEmail.exists) return docEmail;

        var query = await FirebaseFirestore.instance
            .collection('accountant_profile')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) return query.docs.first;
      }
    } catch (e) {
      print('Error al obtener perfil de contador: $e');
    }
    return null;
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _getClientsStream() {
    final user = FirebaseAuth.instance.currentUser;
    final String email = (user?.email ?? 'masexactoa.i@gmail.com').toLowerCase().trim();
    final String uid = user?.uid ?? '';

    return FirebaseFirestore.instance.collection('users').snapshots().handleError((error) {
      print('Error en stream de usuarios: $error');
    }).asyncMap((usersSnap) async {
      QuerySnapshot<Map<String, dynamic>>? clientsSnap;
      try {
        clientsSnap = await FirebaseFirestore.instance.collection('clients').get();
      } catch (_) {}

      Map<String, DocumentSnapshot<Map<String, dynamic>>> combined = {};

      for (var doc in usersSnap.docs) {
        combined[doc.id] = doc;
      }
      if (clientsSnap != null) {
        for (var doc in clientsSnap.docs) {
          if (!combined.containsKey(doc.id)) {
            combined[doc.id] = doc;
          }
        }
      }

      return combined.values.where((doc) {
        var data = doc.data();
        if (data == null) return false;

        String role = (data['role'] ?? 'client').toString().toLowerCase();
        if (role == 'admin' || role == 'accountant' || role == 'contador') return false;

        String accId = (data['accountantId'] ?? '').toString().toLowerCase().trim();

        bool isMasterAccountant = email == 'masexactoa.i@gmail.com' ||
            email == 'castillo8505@gmail.com' ||
            email == 'masexacto@gmail.com' ||
            email.isEmpty;

        bool matches = isMasterAccountant ||
            (accId == email) ||
            (accId == uid.toLowerCase()) ||
            (email.isNotEmpty && accId.contains(email)) ||
            (accId.isEmpty);

        return matches;
      }).toList();
    });
  }

  Future<void> _deleteClient(BuildContext context, String clientId, String businessName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de que deseas eliminar a "$businessName"? Esta acción no se puede deshacer.'),
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
        await FirebaseFirestore.instance.collection('users').doc(clientId).delete();
        await FirebaseFirestore.instance.collection('clients').doc(clientId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente eliminado correctamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String accountantEmail = FirebaseAuth.instance.currentUser?.email ?? 'Contador';

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Contador ($accountantEmail)', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            tooltip: 'Perfil y Logo de la Empresa',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountantProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginView()),
                (route) => false,
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
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta de perfil de la empresa / contador
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                      future: _getAccountantProfile(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.business, size: 40, color: Colors.indigo),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Perfil de la Empresa / Estudio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('Configura tus datos fiscales y logo corporativo.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AccountantProfileScreen()),
                                      ).then((_) => setState(() {}));
                                    },
                                    icon: const Icon(Icons.settings, size: 16),
                                    label: const Text('Configurar'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data!.data()!;
                        final companyName = data['companyName'] ?? 'Mi Estudio Contable';
                        final rif = data['rif'] ?? '';
                        final logoBase64 = data['logoBase64'];

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Builder(
                                  builder: (context) {
                                    final logoBytes = safeBase64Decode(logoBase64);
                                    return Container(
                                      width: 55,
                                      height: 55,
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.indigo.shade200),
                                      ),
                                      child: logoBytes != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.all(4.0),
                                                child: Image.memory(
                                                  logoBytes,
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.business, color: Colors.indigo, size: 28),
                                                ),
                                              ),
                                            )
                                          : const Icon(Icons.business, color: Colors.indigo, size: 28),
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        companyName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                                      ),
                                      const SizedBox(height: 2),
                                      if (rif.isNotEmpty)
                                        Text('RIF: $rif', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AccountantProfileScreen()),
                                    ).then((_) => setState(() {}));
                                  },
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Editar Perfil / Logo'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Tarjeta de bienvenida, botón de añadir cliente y barra de búsqueda
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Gestión de Clientes y Tributos',
                                    style: TextStyle(
                                      fontSize: isMobile ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => const AddClientDialog(),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: Text(isMobile ? 'Nuevo' : 'Nuevo Cliente'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase().trim();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Buscar cliente por nombre o RIF...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Lista de Clientes Registrados',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const Divider(height: 20),

                    // Listado de clientes vinculados a este contador
                    Expanded(
                      child: StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                        stream: _getClientsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          var docs = snapshot.data ?? [];

                          var clients = docs.where((doc) {
                            var data = doc.data();
                            if (data == null) return false;
                            String businessName = (data['businessName'] ?? '').toString().toLowerCase();
                            String taxId = (data['taxId'] ?? '').toString().toLowerCase();
                            String role = (data['role'] ?? 'client');

                            if (role == 'admin') return false;

                            if (_searchQuery.isNotEmpty) {
                              return businessName.contains(_searchQuery) || taxId.contains(_searchQuery);
                            }
                            return true;
                          }).toList();

                          clients.sort((a, b) {
                            String nameA = (a.data()?['businessName'] ?? '').toString().toLowerCase();
                            String nameB = (b.data()?['businessName'] ?? '').toString().toLowerCase();
                            return nameA.compareTo(nameB);
                          });

                          if (clients.isEmpty) {
                            return const Center(
                              child: Text(
                                'No tienes clientes asignados en este momento.',
                                style: TextStyle(color: Colors.grey, fontSize: 15),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: clients.length,
                            itemBuilder: (context, index) {
                              var clientDoc = clients[index];
                              var data = clientDoc.data() as Map<String, dynamic>;

                              String clientId = clientDoc.id;
                              String businessName = data['businessName'] ?? 'Sin Nombre';
                              String taxId = data['taxId'] ?? 'N/D';
                              String email = data['email'] ?? 'Sin Correo';
                              String? logoBase64 = data['logoBase64'];
                              double pendingTax = (data['pendingTaxAmount'] ?? 0.0).toDouble();

                              ClientModel clientModel = ClientModel(
                                clientId: clientId,
                                businessName: businessName,
                                email: email,
                                taxId: taxId,
                                accountantId: accountantEmail,
                                logoBase64: logoBase64,
                                pendingTaxAmount: pendingTax,
                              );

                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: Builder(
                                    builder: (context) {
                                      final logoBytes = safeBase64Decode(logoBase64);
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.indigo.shade100),
                                        ),
                                        child: logoBytes != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.memory(
                                                  logoBytes,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.business, color: Colors.indigo),
                                                ),
                                              )
                                            : const Icon(Icons.business, color: Colors.indigo),
                                      );
                                    },
                                  ),
                                  title: Text(
                                    businessName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('RIF: $taxId', style: const TextStyle(fontSize: 13)),
                                      Text('Impuestos por Pagar: Bs. ${pendingTax.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditClientScreen(client: clientModel),
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        _deleteClient(context, clientId, businessName);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18, color: Colors.indigo),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClientDetailScreen(client: clientModel),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}