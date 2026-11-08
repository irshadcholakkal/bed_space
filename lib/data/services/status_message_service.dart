import 'package:intl/intl.dart';
import '../models/billing_snapshot.dart';
import '../models/payment_model.dart';

class StatusMessageService {
  static String money(double amount) => 'AED ${amount.toStringAsFixed(2)}';

  static String paymentStatus(BillingSnapshot bill, {DateTime? now}) =>
      'Hello ${bill.tenant.tenantName},\n\nRent payment status - ${bill.monthLabel}\n'
      '${bill.buildingName}\n${bill.roomName}\n'
      'Status: ${bill.status(now ?? DateTime.now())}\n'
      'Rent: ${money(bill.rent)}\nPaid: ${money(bill.paid)}\n'
      'Outstanding: ${money(bill.due)}'
      '${bill.credit > 0 ? '\nCredit: ${money(bill.credit)}' : ''}\n'
      'Due date: ${DateFormat('dd MMM yyyy').format(bill.dueDate)}\n\n'
      '${bill.due > 0 ? 'Please arrange the remaining payment. Thank you.' : 'Thank you for your payment.'}';

  static String rentReminder(BillingSnapshot bill) =>
      'Hello ${bill.tenant.tenantName},\n\nRent reminder - ${bill.monthLabel}\n'
      '${bill.buildingName}\n${bill.roomName}\n'
      'Due date: ${DateFormat('dd MMM yyyy').format(bill.dueDate)}\n'
      'Outstanding: ${money(bill.due)}\n\n'
      '${bill.due > 0 ? 'Please arrange payment. Thank you.' : 'There is no outstanding rent for this month. Thank you.'}';

  static String checkout(BillingSnapshot bill, {DateTime? now}) {
    final tenant = bill.tenant;
    final date = tenant.checkoutDate;
    final today = now ?? DateTime.now();
    final scheduled = tenant.active &&
        date != null &&
        DateTime(date.year, date.month, date.day)
            .isAfter(DateTime(today.year, today.month, today.day));
    final status = !tenant.active
        ? 'Checked out'
        : scheduled
            ? 'Checkout scheduled'
            : 'Active tenancy';
    return 'Hello ${tenant.tenantName},\n\nTenancy status: $status\n'
        '${bill.buildingName}\n${bill.roomName}\n'
        '${date == null ? 'No checkout date is scheduled.' : 'Checkout date: ${DateFormat('dd MMM yyyy').format(date)}'}\n'
        '\nPlease contact management for any checkout or settlement questions.';
  }

  static String receipt(BillingSnapshot bill, PaymentModel payment) =>
      'Hello ${bill.tenant.tenantName},\n\nPayment received - thank you.\n'
      'Receipt: ${BillingSnapshot.receiptNumber(payment)}\n'
      '${bill.buildingName}\n${bill.roomName}\n'
      'Rent month: ${bill.monthLabel}\n'
      'Amount received: ${money(payment.amount)}\n'
      'Paid on: ${DateFormat('dd MMM yyyy').format(payment.paidDate)}';

  static String vacancy(
          {required String building,
          required String address,
          required String room,
          required String bedType,
          required double rent,
          int count = 1}) =>
      'Bed space available\n\n$building${address.trim().isEmpty ? '' : '\n$address'}\n'
      '$room\n$bedType bed${count == 1 ? '' : 's'} available: $count\n'
      'Monthly rent: ${money(rent)} per bed\n\nContact management for details and viewing.';

  /// Accepts explicit international numbers and common UAE mobile formats.
  static String normalizePhone(String input) {
    if (!RegExp(r'^[+\d\s().-]+$').hasMatch(input.trim())) {
      throw ArgumentError('Enter a valid phone number including country code.');
    }
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (RegExp(r'^05\d{8}$').hasMatch(digits)) {
      digits = '971${digits.substring(1)}';
    }
    if (RegExp(r'^5\d{8}$').hasMatch(digits)) digits = '971$digits';
    if (!RegExp(r'^[1-9]\d{7,14}$').hasMatch(digits)) {
      throw ArgumentError(
          'Enter an international number, for example +971501234567.');
    }
    return digits;
  }

  static Uri whatsappUri(String message, {String? phone}) => Uri.https(
      'wa.me',
      phone == null || phone.trim().isEmpty ? '/' : '/${normalizePhone(phone)}',
      {'text': message});
}
