/// Expense types for room maintenance
enum ExpenseType {
  rent, // Rent paid to landlord
  sewa, // Electricity/Water
  maintenance, // Repairs
  internet, // WiFi bill
  cleaning, // Cleaning services
  refund, // Rent refund on checkout
  other // Miscellaneous
}

class ExpenseModel {
  final String? id;
  final String roomId;
  final String?
      tenantId; // Optional: Link expense to a specific tenant (e.g., refunds)
  final ExpenseType expenseType;
  final double amount;
  final DateTime date;
  final String? description;

  ExpenseModel({
    this.id,
    required this.roomId,
    this.tenantId,
    required this.expenseType,
    required this.amount,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'tenant_id': tenantId,
      'expense_type': expenseType.toString().split('.').last.toUpperCase(),
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String?,
      roomId: json['room_id'] as String,
      tenantId: json['tenant_id'] as String?,
      expenseType: _parseExpenseType(json['expense_type'] as String),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
    );
  }

  static ExpenseType _parseExpenseType(String type) {
    return ExpenseType.values.firstWhere(
      (e) => e.toString().split('.').last.toUpperCase() == type.toUpperCase(),
      orElse: () => ExpenseType.other,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? roomId,
    String? tenantId,
    ExpenseType? expenseType,
    double? amount,
    DateTime? date,
    String? description,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      tenantId: tenantId ?? this.tenantId,
      expenseType: expenseType ?? this.expenseType,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
    );
  }
}
