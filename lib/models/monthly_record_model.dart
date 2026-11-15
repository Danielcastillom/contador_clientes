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

  factory MonthlyRecordModel.fromMap(Map<String, dynamic> map, String id) {
    return MonthlyRecordModel(
      recordId: id,
      year: map['year'] ?? 2026,
      month: map['month'] ?? 1,
      totalIncome: (map['totalIncome'] ?? 0.0).toDouble(),
      totalExpenses: (map['totalExpenses'] ?? 0.0).toDouble(),
      taxPayable: (map['taxPayable'] ?? 0.0).toDouble(),
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