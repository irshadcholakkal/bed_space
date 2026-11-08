import 'dart:io';
import 'package:bed_space/data/models/billing_snapshot.dart';
import 'package:bed_space/data/models/payment_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/services/status_message_service.dart';
import 'package:bed_space/data/services/billing_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bed_space/presentation/widgets/sharing_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tenant = TenantModel(
      tenantId: 'tenant-1',
      tenantName: 'Alex Morgan',
      phone: '+971501234567',
      buildingId: 'building',
      roomId: 'room',
      bedId: 'bed',
      rentAmount: 900,
      advanceAmount: 500,
      joiningDate: DateTime(2026, 9, 1),
      rentDueDay: 5,
      active: true);
  final payment = PaymentModel(
      paymentId: 'payment-1',
      tenantId: 'tenant-1',
      amount: 400,
      paymentMonth: '2026-11',
      paidDate: DateTime(2026, 11, 3));
  BillingSnapshot bill(Iterable<PaymentModel> payments) => BillingSnapshot(
      tenant: tenant,
      month: '2026-11',
      buildingName: 'Palm Residence',
      roomName: 'Room 101 / Subroom A',
      payments: payments);

  testWidgets(
      'billing actions show invoice, receipt and editable WhatsApp draft',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(home: BillingActionsScreen(bill: bill([payment]))));
    expect(find.text('Rent invoice'), findsOneWidget);
    expect(find.text('Payment receipts'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Open WhatsApp'), findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller!.text, tenant.phone);
    expect(fields.last.controller!.text, contains('AED 500.00'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'statuses and balances cover unpaid, due today, overdue, partial, paid and credit',
      () {
    expect(bill([]).status(DateTime(2026, 11, 1)), 'Unpaid');
    expect(bill([]).status(DateTime(2026, 11, 5)), 'Due today');
    expect(bill([]).status(DateTime(2026, 11, 8)), 'Overdue');
    expect(bill([payment]).status(DateTime(2026, 11, 8)), 'Partially paid');
    expect(bill([payment]).due, 500);
    final full = PaymentModel(
        paymentId: 'full',
        tenantId: 'tenant-1',
        amount: 900,
        paymentMonth: '2026-11',
        paidDate: DateTime(2026, 11, 3));
    expect(bill([full]).status(DateTime(2026, 11, 8)), 'Paid');
    expect(bill([full, payment]).credit, 400);
    expect(bill([full, payment]).due, 0);
    expect(bill([full, payment]).status(DateTime(2026, 11, 8)), 'Overpaid');
  });

  test('billing excludes other months and tenants and handles partial stays',
      () {
    expect(
        bill([
          PaymentModel(
              tenantId: 'other',
              amount: 900,
              paymentMonth: '2026-11',
              paidDate: DateTime(2026))
        ]).paid,
        0);
    expect(
        BillingSnapshot.rentForMonth(
            tenant.copyWith(joiningDate: DateTime(2026, 11, 16)),
            DateTime(2026, 11)),
        450);
    expect(
        BillingSnapshot.rentForMonth(
            tenant.copyWith(
                checkoutDate: DateTime(2026, 10, 31), active: false),
            DateTime(2026, 11)),
        0);
    expect(bill([]).invoiceNumber, bill([payment]).invoiceNumber);
  });

  test('WhatsApp messages preserve details and safely encode text and numbers',
      () {
    final text = StatusMessageService.paymentStatus(bill([payment]),
        now: DateTime(2026, 11, 8));
    expect(text, contains('Outstanding: AED 500.00'));
    expect(text, contains('Subroom A'));
    expect(StatusMessageService.whatsappUri(text, phone: '050 123 4567').path,
        '/971501234567');
    expect(
        StatusMessageService.whatsappUri(text).queryParameters['text'], text);
    expect(
        () => StatusMessageService.normalizePhone('abc'), throwsArgumentError);
    expect(StatusMessageService.checkout(bill([])), contains('Active tenancy'));
    expect(
        StatusMessageService.vacancy(
            building: 'Palm',
            address: '',
            room: '101',
            bedType: 'Lower',
            rent: 650),
        contains('AED 650.00'));
  });

  test(
      'invoice and receipt generate valid PDFs; receipt rejects unrelated payments',
      () async {
    final snapshot = bill([payment]);
    final invoice = await BillingPdfService.generate(snapshot,
        issuedAt: DateTime(2026, 11, 8));
    final receipt = await BillingPdfService.generate(snapshot,
        payment: payment, issuedAt: DateTime(2026, 11, 8));
    expect(String.fromCharCodes(invoice.take(4)), '%PDF');
    expect(String.fromCharCodes(receipt.take(4)), '%PDF');
    await expectLater(
        BillingPdfService.generate(snapshot,
            payment: PaymentModel(
                paymentId: 'other',
                tenantId: 'other',
                amount: 1,
                paymentMonth: '2026-11',
                paidDate: DateTime(2026))),
        throwsArgumentError);
    // Opt-in artifacts for visual QA; normal test runs do not write files.
    if (Platform.environment['BILLING_PDF_QA'] == '1') {
      final directory = Directory('.dart_tool/billing-qa')
        ..createSync(recursive: true);
      await File('${directory.path}/invoice.pdf').writeAsBytes(invoice);
      await File('${directory.path}/receipt.pdf').writeAsBytes(receipt);
    }
  });
}
