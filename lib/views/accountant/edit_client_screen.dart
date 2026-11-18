import 'dart:convert' as convert;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _logoBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client.businessName);
    _taxIdController = TextEditingController(text: widget.client.taxId);
    _emailController = TextEditingController(text: widget.client.email);
    _pendingTaxController = TextEditingController(text: widget.client.pendingTaxAmount.toStringAsFixed(2).replaceFirst('.', ','));
    _logoBase64 = widget.client.logoBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taxIdController.dispose();
    _emailController.dispose();
    _pendingTaxController.dispose();
    super.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _updateClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updateData = {
        'businessName': _nameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'email': _emailController.text.trim(),
        'pendingTaxAmount': double.tryParse(_pendingTaxController.text.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0,
        'logoBase64': _logoBase64,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.client.clientId).set(updateData, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('clients').doc(widget.client.clientId).set(updateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cliente y logo actualizados exitosamente!')),
        );
        Navigator.pop(context, true);
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
                    'Actualizar Datos y Logo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 20),

                  // Sección del Logo de la Empresa
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickLogo,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.indigo.shade200, width: 2),
                            ),
                            child: _logoBase64 != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      convert.base64Decode(_logoBase64!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: Colors.indigo, size: 36),
                                      SizedBox(height: 4),
                                      Text('Subir Logo', style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.image, size: 18),
                          label: Text(_logoBase64 != null ? 'Cambiar Logo de la Empresa' : 'Agregar Logo de la Empresa'),
                        ),
                      ],
                    ),
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
                    decoration: const InputDecoration(labelText: 'Impuestos por Pagar (Bs.)', border: OutlineInputBorder()),
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
