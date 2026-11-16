class MonthlyRecordModel {
  final String recordId;
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpenses;
  final double taxPayable;
  final String status;
  final List<Map<String, dynamic>> documents;

  MonthlyRecordModel({
    required this.recordId,
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.taxPayable,
    required this.status,
    required this.documents,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory MonthlyRecordModel.fromMap(Map<String, dynamic> map, String id) {
    return MonthlyRecordModel(
      recordId: id,
      year: map['year'] is num ? (map['year'] as num).toInt() : int.tryParse(map['year']?.toString() ?? '') ?? 2026,
      month: map['month'] is num ? (map['month'] as num).toInt() : int.tryParse(map['month']?.toString() ?? '') ?? 1,
      totalIncome: _parseDouble(map['totalIncome']),
      totalExpenses: _parseDouble(map['totalExpenses']),
      taxPayable: _parseDouble(map['taxPayable']),
      status: map['status'] ?? 'Pending',
      documents: List<Map<String, dynamic>>.from(map['documents'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'taxPayable': taxPayable,
      'status': status,
      'documents': documents,
    };
  }
}