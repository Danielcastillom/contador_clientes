import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/client_model.dart';

class EditClientScreen extends StatefulWidget {
  final ClientModel client;

  const EditClientScreen({super.key, required this.client});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _taxIdController;
  late TextEditingController _emailController;
  late TextEditingController _pendingTaxController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client.businessName);
    _taxIdController = TextEditingController(text: widget.client.taxId);
    _emailController = TextEditingController(text: widget.client.email);
    _pendingTaxController = TextEditingController(text: widget.client.pendingTaxAmount.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taxIdController.dispose();
    _emailController.dispose();
    _pendingTaxController.dispose();
    super.dispose();
  }

  Future<void> _updateClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updateData = {
        'businessName': _nameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'email': _emailController.text.trim(),
        'pendingTaxAmount': double.tryParse(_pendingTaxController.text.trim()) ?? 0.0,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.client.clientId).set(updateData, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('clients').doc(widget.client.clientId).set(updateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente actualizado exitosamente')),
        );
        Navigator.pop(context, true); // Regresa indicando éxito
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Cliente'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    'Actualizar Datos Fiscales',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre de la Empresa o Cliente', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Por favor ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Por favor ingresa el correo' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxIdController,
                    decoration: const InputDecoration(labelText: 'RIF / Identificación Fiscal', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Por favor ingresa el RIF' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pendingTaxController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Impuestos por Pagar (\$)', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Ingresa el monto' : null,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateClient,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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