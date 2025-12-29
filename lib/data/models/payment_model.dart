/// Payment data model
class PaymentModel {
  final String? paymentId;
  final String tenantId;
  final double amount;
  final String paymentMonth; // Format: YYYY-MM
  final DateTime paidDate;

  PaymentModel({
    this.paymentId,
    required this.tenantId,
    required this.amount,
    required this.paymentMonth,
    required this.paidDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId ?? '',
      'tenant_id': tenantId,
      'amount': amount,
      'payment_month': paymentMonth,
      'paid_date': paidDate.toIso8601String().split('T')[0],
    };
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: json['payment_id']?.toString(),
      tenantId: json['tenant_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentMonth: json['payment_month']?.toString() ?? '',
      paidDate: DateTime.tryParse(json['paid_date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

