import 'dart:convert' as convert;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AccountantInfoCard extends StatelessWidget {
  final Map<String, dynamic>? accountantData;
  final bool isEditable;
  final VoidCallback? onEdit;
  final String? subtitle;

  const AccountantInfoCard({
    super.key,
    required this.accountantData,
    this.isEditable = false,
    this.onEdit,
    this.subtitle,
  });

  Uint8List? _decodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return convert.base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = accountantData ?? {};
    final String companyName = data['companyName']?.toString().trim() ?? '';
    final String rif = data['rif']?.toString().trim() ?? '';
    final String phone = data['phone']?.toString().trim() ?? '';
    final String address = data['address']?.toString().trim() ?? '';
    final String email = data['email']?.toString().trim() ??
        data['accountantEmail']?.toString().trim() ??
        '';
    final Uint8List? logoBytes = _decodeBase64(data['logoBase64']);

    final bool hasInfo = companyName.isNotEmpty || rif.isNotEmpty || logoBytes != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade100, width: 1.2),
      ),
      color: Colors.indigo.shade50.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila principal: Logo en la esquina izquierda + Datos del Despacho Contable
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo en la esquina izquierda
                GestureDetector(
                  onTap: isEditable ? onEdit : null,
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoBytes != null
                        ? Image.memory(
                            logoBytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.business,
                              color: Colors.indigo,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.account_balance,
                            color: Colors.indigo,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Información de la Empresa Contable
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subtitle ?? (isEditable ? 'MI EMPRESA CONTABLE' : 'ASESOR CONTABLE'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isEditable && onEdit != null)
                            InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.edit, size: 14, color: Colors.indigo),
                                    SizedBox(width: 4),
                                    Text(
                                      'Editar Perfil',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        companyName.isNotEmpty
                            ? companyName
                            : (isEditable
                                ? 'Configura el nombre de tu empresa'
                                : 'Despacho Contable'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: companyName.isNotEmpty ? Colors.indigo.shade900 : Colors.grey.shade600,
                        ),
                      ),
                      if (rif.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              'RIF: $rif',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (email.isNotEmpty && !isEditable) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              email,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                      if (!hasInfo && isEditable) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Toca en "Editar Perfil" para agregar tu RIF, teléfono, dirección y logo.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
