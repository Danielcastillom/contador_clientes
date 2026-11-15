class ClientModel {
  final String clientId;
  final String businessName;
  final String email;
  final String taxId;
  final String accountantId;
  final String? logoBase64;       // Logo específico del cliente
  final double pendingTaxAmount;  // Impuestos pendientes por pagar

  ClientModel({
    required this.clientId,
    required this.businessName,
    required this.email,
    required this.taxId,
    required this.accountantId,
    this.logoBase64,
    this.pendingTaxAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'email': email,
      'taxId': taxId,
      'accountantId': accountantId,
      'logoBase64': logoBase64,
      'pendingTaxAmount': pendingTaxAmount,
    };
  }

  // Acepta primero el Map y luego el ID (como lo está llamando database_service.dart)
  factory ClientModel.fromMap(Map<String, dynamic> map, String id) {
    return ClientModel(
      clientId: id,
      businessName: map['businessName'] ?? map['name'] ?? '',
      email: map['email'] ?? '',
      taxId: map['taxId'] ?? map['rif'] ?? '',
      accountantId: map['accountantId'] ?? '',
      logoBase64: map['logoBase64'],
      pendingTaxAmount: (map['pendingTaxAmount'] ?? 0.0).toDouble(),
    );
  }
}