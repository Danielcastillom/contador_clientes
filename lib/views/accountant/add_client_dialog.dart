import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AddClientDialog extends StatefulWidget {
  const AddClientDialog({super.key});

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _pendingTaxController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _taxIdController.dispose();
    _pendingTaxController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    FirebaseApp? tempApp;

    try {
      String accountantEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      // 1. Crear usuario en Firebase Auth usando una instancia temporal para mantener la sesión del contador activa
      String tempAppName = 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String clientUid = userCredential.user!.uid;

      // 2. Guardar los datos del cliente en la colección 'users' usando el UID de Auth
      Map<String, dynamic> clientData = {
        'businessName': _businessNameController.text.trim(),
        'email': email,
        'taxId': _taxIdController.text.trim(),
        'pendingTaxAmount': double.tryParse(_pendingTaxController.text.trim()) ?? 0.0,
        'role': 'client',
        'accountantId': accountantEmail,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(clientUid).set(clientData);

      // Guardar también en la colección 'clients' para compatibilidad total
      await FirebaseFirestore.instance.collection('clients').doc(clientUid).set(clientData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true); // Cierra el modal y avisa éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cliente y cuenta creados exitosamente!')),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error al crear la cuenta: ${e.message}';
      if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya está registrado en Firebase Auth.';
      } else if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil (mínimo 6 caracteres).';
      } else if (e.code == 'invalid-email') {
        message = 'El correo electrónico no es válido.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el cliente: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Nuevo Cliente', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Nombre de la Empresa o Cliente', prefixIcon: Icon(Icons.business)),
                  validator: (value) => value!.isEmpty ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico (Login)', prefixIcon: Icon(Icons.email)),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Ingresa el correo';
                    if (!value.contains('@')) return 'Ingresa un correo válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña Inicial para el Cliente',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Ingresa una contraseña';
                    if (value.trim().length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxIdController,
                  decoration: const InputDecoration(labelText: 'RIF / Identificación Fiscal', prefixIcon: Icon(Icons.badge)),
                  validator: (value) => value!.isEmpty ? 'Ingresa el RIF' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pendingTaxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Impuestos por Pagar (\$)', prefixIcon: Icon(Icons.attach_money)),
                  validator: (value) => value!.isEmpty ? 'Ingresa el monto inicial' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveClient,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }
}