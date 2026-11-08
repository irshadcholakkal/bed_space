import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'payment_model.dart';
import 'tenant_model.dart';

class BillingSnapshot {
  final TenantModel tenant;
  final String month;
  final String buildingName;
  final String roomName;
  final List<PaymentModel> payments;

  BillingSnapshot({required this.tenant, required this.month,
    required this.buildingName, required this.roomName,
    required Iterable<PaymentModel> payments})
      : payments = List.unmodifiable(payments.where((payment) =>
          payment.tenantId == tenant.tenantId && payment.paymentMonth == month)) {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
      throw ArgumentError('Choose a valid billing month.');
    }
  }

  DateTime get period => DateTime.parse('$month-01');
  String get monthLabel => DateFormat('MMMM yyyy').format(period);
  double get rent => rentForMonth(tenant, period);
  double get paid => payments.fold(0, (sum, payment) => sum + payment.amount);
  double get due => math.max(0, rent - paid);
  double get credit => math.max(0, paid - rent);
  DateTime get dueDate => DateTime(period.year, period.month,
      tenant.rentDueDay.clamp(1, DateTime(period.year, period.month + 1, 0).day));
  String get invoiceNumber => 'INV-${month.replaceAll('-', '')}-${const Uuid().v5(Namespace.url, '${tenant.tenantId}/$month').replaceAll('-', '').substring(0, 16).toUpperCase()}';

  String status(DateTime now) {
    if (credit > 0.005) return 'Overpaid';
    if (due < 0.005) return 'Paid';
    if (paid > 0) return 'Partially paid';
    final today = DateTime(now.year, now.month, now.day);
    if (today.isAfter(dueDate)) return 'Overdue';
    if (today == dueDate) return 'Due today';
    return 'Unpaid';
  }

  static double rentForMonth(TenantModel tenant, DateTime period) {
    final start = DateTime(period.year, period.month);
    final end = DateTime(period.year, period.month + 1, 0);
    final join = DateTime(tenant.joiningDate.year, tenant.joiningDate.month, tenant.joiningDate.day);
    final checkout = tenant.checkoutDate;
    final leave = checkout == null ? null : DateTime(checkout.year, checkout.month, checkout.day);
    if (join.isAfter(end) || (leave != null && leave.isBefore(start))) return 0;
    if ((join.year == start.year && join.month == start.month) ||
        (leave != null && leave.year == start.year && leave.month == start.month)) {
      final from = join.isAfter(start) ? join.day : 1;
      final to = leave != null && leave.isBefore(end) ? leave.day : end.day;
      return tenant.rentAmount / 30 * math.max(0, to - from + 1);
    }
    return tenant.rentAmount;
  }

  static String receiptNumber(PaymentModel payment) {
    if (payment.paymentId == null || payment.paymentId!.isEmpty ||
        payment.amount <= 0 || !payment.amount.isFinite) {
      throw ArgumentError('A receipt requires a saved, positive payment.');
    }
    return 'RCT-${const Uuid().v5(Namespace.url, payment.paymentId!).replaceAll('-', '').substring(0, 16).toUpperCase()}';
  }
}
