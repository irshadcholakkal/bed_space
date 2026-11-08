import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/billing_snapshot.dart';
import '../models/payment_model.dart';

class BillingPdfService {
  static Future<Uint8List> generate(BillingSnapshot bill,
      {PaymentModel? payment, DateTime? issuedAt}) async {
    final receipt = payment != null;
    if (payment != null &&
        (payment.tenantId != bill.tenant.tenantId ||
            payment.paymentMonth != bill.month)) {
      throw ArgumentError(
          'The payment does not belong to this tenant and month.');
    }
    final number =
        receipt ? BillingSnapshot.receiptNumber(payment) : bill.invoiceNumber;
    final date = issuedAt ?? DateTime.now();
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final pdf = pw.Document(
        title: '${receipt ? 'Receipt' : 'Invoice'} $number',
        author: 'Bed Space Management');
    final accent = PdfColor.fromHex('#ff385c');
    String money(double amount) => 'AED ${amount.toStringAsFixed(2)}';
    pw.Widget row(String label, String value, {bool bold = false}) =>
        pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(label)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontWeight: bold ? pw.FontWeight.bold : null))
            ]));
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      margin: const pw.EdgeInsets.all(40),
      footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Bed Space Management',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9)),
          ]),
      build: (context) => [
        pw.Text('BED SPACE MANAGEMENT',
            style: pw.TextStyle(
                fontSize: 12, color: accent, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        pw.Text(receipt ? 'PAYMENT RECEIPT' : 'RENT INVOICE',
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(number, style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Issued: ${DateFormat('dd MMM yyyy').format(date)}'),
        pw.SizedBox(height: 24),
        pw.Text(receipt ? 'Received from' : 'Bill to',
            style: const pw.TextStyle(color: PdfColors.grey600)),
        pw.SizedBox(height: 5),
        pw.Text(bill.tenant.tenantName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(bill.tenant.phone),
        pw.Text(bill.buildingName),
        pw.Text(bill.roomName),
        pw.SizedBox(height: 24),
        pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.all(12),
            child: pw.Text('Rent period: ${bill.monthLabel}')),
        pw.SizedBox(height: 12),
        if (receipt) ...[
          row('Payment date',
              DateFormat('dd MMM yyyy').format(payment.paidDate)),
          row('Amount received', money(payment.amount), bold: true),
          pw.SizedBox(height: 10),
          pw.Text('Payment reference: ${payment.paymentId}'),
          pw.SizedBox(height: 24),
          pw.Text(
              'Thank you. This receipt acknowledges only the payment recorded above.'),
        ] else ...[
          row('Rent for this period', money(bill.rent)),
          row('Payments recorded', money(bill.paid)),
          pw.Divider(color: accent),
          row('Balance due', money(bill.due), bold: true),
          if (bill.credit > 0) row('Credit', money(bill.credit)),
          row('Due date', DateFormat('dd MMM yyyy').format(bill.dueDate)),
          row('Status', bill.status(date)),
          pw.SizedBox(height: 24),
          pw.Text('Please quote the invoice number when arranging payment.'),
          pw.SizedBox(height: 8),
          pw.Text(
              'Partial months use the app\'s 30-day rent calculation. Advance deposits and checkout refunds are handled separately.',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ],
    ));
    return pdf.save();
  }
}
