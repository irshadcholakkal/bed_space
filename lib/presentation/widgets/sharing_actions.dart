import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/billing_snapshot.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/tenant_model.dart';
import '../../data/services/billing_pdf_service.dart';
import '../../data/services/status_message_service.dart';
import '../blocs/management/management_bloc.dart';
import 'package:http/http.dart' as http;
import '../../data/services/saas_service.dart';
import '../../data/services/google_drive_service.dart';
import '../../data/repositories/sheet_repository.dart';

Future<void> showWhatsAppDraft(BuildContext context,
    {required String message, String phone = ''}) async {
  final text = TextEditingController(text: message);
  final recipient = TextEditingController(text: phone);
  String? error;
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
          builder: (context, setState) => SafeArea(
                  child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text('WhatsApp message',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(
                          controller: recipient,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Recipient phone (optional)',
                              helperText:
                                  'Include country code. Leave empty to choose in WhatsApp.')),
                      const SizedBox(height: 16),
                      TextField(
                          controller: text,
                          minLines: 6,
                          maxLines: 12,
                          decoration:
                              const InputDecoration(labelText: 'Message')),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      const Text(
                          'Review the message, then choose Send in WhatsApp. PDF files can be attached after downloading or sharing them.'),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, children: [
                        OutlinedButton.icon(
                            icon: const Icon(CupertinoIcons.doc_on_doc),
                            label: const Text('Copy'),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: text.text));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Message copied')));
                              }
                            }),
                        FilledButton.icon(
                            icon: const Icon(CupertinoIcons.chat_bubble),
                            label: const Text('Open WhatsApp'),
                            onPressed: () async {
                              try {
                                final uri = StatusMessageService.whatsappUri(
                                    text.text,
                                    phone: recipient.text);
                                final opened = await launchUrl(uri,
                                    mode: LaunchMode.externalApplication,
                                    webOnlyWindowName: '_blank');
                                if (!opened && context.mounted) {
                                  setState(() => error =
                                      'Could not open WhatsApp. You can copy the message instead.');
                                }
                              } catch (exception) {
                                if (context.mounted) {
                                  setState(() => error = exception
                                          is ArgumentError
                                      ? exception.message.toString()
                                      : 'Could not open WhatsApp. Copy the message instead.');
                                }
                              }
                            }),
                      ]),
                    ])),
              ))));
  // Controllers remain alive through the bottom sheet's closing animation.
}

BillingSnapshot billingFromState(
    ManagementLoaded state, TenantModel tenant, String month) {
  final room =
      state.rooms.where((room) => room.roomId == tenant.roomId).firstOrNull;
  final building = state.buildings
      .where((building) => building.buildingId == tenant.buildingId)
      .firstOrNull;
  return BillingSnapshot(
      tenant: tenant,
      month: month,
      buildingName: building?.buildingName ?? 'Building ${tenant.buildingId}',
      roomName: room?.displayName(state.rooms) ?? 'Room ${tenant.roomId}',
      payments: state.payments);
}

Future<void> openTenantSharing(BuildContext context, TenantModel tenant,
    {String? month, PaymentModel? payment}) async {
  final state = context.read<ManagementBloc>().state;
  if (state is! ManagementLoaded) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tenant data is still loading. Please try again.')));
    return;
  }
  final bill = billingFromState(
      state,
      tenant,
      payment?.paymentMonth ??
          month ??
          DateFormat('yyyy-MM').format(DateTime.now()));
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          BillingActionsScreen(bill: bill, selectedPayment: payment)));
}

class BillingActionsScreen extends StatefulWidget {
  final BillingSnapshot bill;
  final PaymentModel? selectedPayment;
  const BillingActionsScreen(
      {super.key, required this.bill, this.selectedPayment});
  @override
  State<BillingActionsScreen> createState() => _BillingActionsScreenState();
}

class _BillingActionsScreenState extends State<BillingActionsScreen> {
  bool busy = false;
  Future<void> document(
      {PaymentModel? payment, bool print = false, bool drive = false}) async {
    setState(() => busy = true);
    try {
      final bytes =
          await BillingPdfService.generate(widget.bill, payment: payment);
      final name =
          '${payment == null ? widget.bill.invoiceNumber : BillingSnapshot.receiptNumber(payment)}.pdf';
      if (drive) {
        final userId = SaasService.userId;
        final token = await SheetRepository().getToken();
        if (userId == null || token == null) {
          throw StateError('Connect Google before saving documents.');
        }
        final binding = await SaasService.client
            .from('storage_bindings')
            .select('drive_folder_id')
            .eq('user_id', userId)
            .single();
        final folder = binding['drive_folder_id'] as String?;
        if (folder == null) {
          throw StateError('Reconnect Google to set up your document folder.');
        }
        final client = http.Client();
        try {
          await GoogleDriveService(client).uploadPdf(
              token: token, folderId: folder, filename: name, bytes: bytes);
        } finally {
          client.close();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Saved a PDF copy to your Google Drive folder.')));
        }
      } else if (print) {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: name);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to create document: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final payments = widget.selectedPayment == null
        ? bill.payments
        : [widget.selectedPayment!];
    return Scaffold(
        appBar: AppBar(title: const Text('Messages & documents')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(bill.tenant.tenantName,
              style: Theme.of(context).textTheme.headlineSmall),
          Text('${bill.buildingName}\n${bill.roomName}\n${bill.monthLabel}'),
          const SizedBox(height: 16),
          Text(
              '${bill.status(DateTime.now())} • Due ${StatusMessageService.money(bill.due)}'),
          const SizedBox(height: 20),
          const Text('WhatsApp messages'),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () => showWhatsAppDraft(context,
                    message: StatusMessageService.paymentStatus(bill),
                    phone: bill.tenant.phone),
                child: const Text('Payment status')),
            OutlinedButton(
                onPressed: () => showWhatsAppDraft(context,
                    message: StatusMessageService.rentReminder(bill),
                    phone: bill.tenant.phone),
                child: const Text('Rent due')),
            OutlinedButton(
                onPressed: () => showWhatsAppDraft(context,
                    message: StatusMessageService.checkout(bill),
                    phone: bill.tenant.phone),
                child: const Text('Checkout status')),
          ]),
          const Divider(height: 32),
          Text('Rent invoice', style: Theme.of(context).textTheme.titleLarge),
          Text(bill.invoiceNumber),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
                onPressed: busy ? null : () => document(),
                icon: const Icon(CupertinoIcons.doc_richtext),
                label: Text(kIsWeb ? 'Download invoice' : 'Share invoice PDF')),
            OutlinedButton(
                onPressed: busy ? null : () => document(print: true),
                child: const Text('Print invoice')),
            if (SaasService.userId != null)
              OutlinedButton.icon(
                  onPressed: busy ? null : () => document(drive: true),
                  icon: const Icon(CupertinoIcons.cloud_upload),
                  label: const Text('Save copy to Drive')),
          ]),
          const Divider(height: 32),
          Text('Payment receipts',
              style: Theme.of(context).textTheme.titleLarge),
          if (payments.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Record a payment to generate a receipt.')),
          for (final payment in payments)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${StatusMessageService.money(payment.amount)} • ${DateFormat('dd MMM yyyy').format(payment.paidDate)}'),
                          Wrap(spacing: 8, children: [
                            if (SaasService.userId != null)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => document(
                                          payment: payment, drive: true),
                                  child: const Text('Save copy to Drive')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => document(payment: payment),
                                child: Text(kIsWeb
                                    ? 'Download receipt'
                                    : 'Share receipt PDF')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                        document(payment: payment, print: true),
                                child: const Text('Print')),
                            TextButton(
                                onPressed: payment.paymentId == null ||
                                        payment.paymentId!.isEmpty
                                    ? null
                                    : () => showWhatsAppDraft(context,
                                        message: StatusMessageService.receipt(
                                            bill, payment),
                                        phone: bill.tenant.phone),
                                child: const Text('WhatsApp')),
                          ]),
                        ]))),
          if (busy) const LinearProgressIndicator(),
        ]));
  }
}
