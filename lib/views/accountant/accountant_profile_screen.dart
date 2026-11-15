import 'dart:convert' as convert;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountantProfileScreen extends StatefulWidget {
  const AccountantProfileScreen({super.key});

  @override
  State<AccountantProfileScreen> createState() => _AccountantProfileScreenState();
}

class _AccountantProfileScreenState extends State<AccountantProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rifController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _logoBase64;
  bool _isLoading = true;
  String accountantId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadAccountantData();
  }

  Future<void> _loadAccountantData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (accountantId.isNotEmpty) {
        var docSnap = await FirebaseFirestore.instance.collection('accountant_profile').doc(accountantId).get();
        if (docSnap.exists) doc = docSnap;
      }

      if (doc == null || !doc.exists) {
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null && email.isNotEmpty) {
          var docEmail = await FirebaseFirestore.instance.collection('accountant_profile').doc(email).get();
          if (docEmail.exists) {
            doc = docEmail;
          } else {
            var query = await FirebaseFirestore.instance
                .collection('accountant_profile')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) {
              doc = query.docs.first;
            }
          }
        }
      }

      if (doc != null && doc.exists) {
        var data = doc.data()!;
        _nameController.text = data['companyName'] ?? '';
        _rifController.text = data['rif'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _logoBase64 = data['logoBase64'];
      }
    } catch (e) {
      print('🔥 Error al cargar perfil: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        Uint8List bytes = result.files.single.bytes!;
        setState(() {
          _logoBase64 = convert.base64Encode(bytes);
        });
      }
    } catch (e) {
      print('🔥 Error al seleccionar logo: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';

      final profileData = {
        'email': email,
        'companyName': _nameController.text.trim(),
        'rif': _rifController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'logoBase64': _logoBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (accountantId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('accountant_profile').doc(accountantId).set(profileData, SetOptions(merge: true));
      }
      if (email.isNotEmpty) {
        await FirebaseFirestore.instance.collection('accountant_profile').doc(email).set(profileData, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Perfil de la empresa actualizado con éxito!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Correo enviado'),
            content: Text('Se ha enviado un enlace para restablecer tu contraseña al correo: ${user.email}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar correo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración y Perfil de la Empresa'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logo Corporativo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _logoBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.memory(
                                    convert.base64Decode(_logoBase64!),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              )
                            : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Subir Logo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Información de la Empresa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const Divider(height: 20),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Empresa / Estudio',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) => value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rifController,
                    decoration: const InputDecoration(
                      labelText: 'RIF (Ej. J-12345678-9)',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) => value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de Contacto',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección Fiscal',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Cambios'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const Divider(height: 48),
                  const Text(
                    'Seguridad de la Cuenta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Cambiar Contraseña (Enviar correo de recuperación)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}