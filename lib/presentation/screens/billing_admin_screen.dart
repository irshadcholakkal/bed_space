import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/billing_admin_service.dart';

String _date(dynamic value) => value == null
    ? '-'
    : DateFormat('dd MMM yyyy')
        .format(DateTime.parse(value as String).toLocal());

class BillingAdminShortcut extends StatefulWidget {
  final Widget child;
  const BillingAdminShortcut({super.key, required this.child});
  @override
  State<BillingAdminShortcut> createState() => _BillingAdminShortcutState();
}

class _BillingAdminShortcutState extends State<BillingAdminShortcut> {
  late final Future<bool> _admin =
      BillingAdminService().isAdmin().catchError((_) => false);
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: widget.child),
        FutureBuilder<bool>(
            future: _admin,
            builder: (context, snapshot) => snapshot.data == true
                ? Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                        heroTag: 'billing-admin',
                        onPressed: () =>
                            context.push('/admin'),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Administration')))
                : const SizedBox()),
      ]);
}

class BillingAdminScreen extends StatefulWidget {
  final BillingAdminService service;
  const BillingAdminScreen(
      {super.key, this.service = const BillingAdminService()});
  @override
  State<BillingAdminScreen> createState() => _BillingAdminScreenState();
}

class _BillingAdminScreenState extends State<BillingAdminScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  bool _busy = false;
  String? _error;
  String _filter = 'all';
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await widget.service.isAdmin()) {
        throw StateError('Not authorized');
      }
      final rows = await widget.service.accounts(_search.text.trim());
      if (mounted) {
        setState(() {
          _accounts = rows;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accounts = [];
          _error =
              'Administration is unavailable. Use an authorized account and check the billing setup.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payment(Map<String, dynamic> account) async {
    final changed = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _ManualPaymentDialog(account: account, service: widget.service));
    if (changed == true) await _load();
  }

  Future<void> _block(Map<String, dynamic> account) async {
    final blocked = account['admin_blocked'] != true;
    String reason = '';
    String? error;
    bool saving = false;
    final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: Text(blocked
                        ? 'Block workspace access'
                        : 'Remove manual block'),
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${account['email']}\n${blocked ? 'The workspace will be blocked.' : 'Removing a block does not extend the trial or paid period.'}'),
                          const SizedBox(height: 16),
                          TextField(
                              enabled: !saving,
                              maxLength: 1000,
                              decoration:
                                  const InputDecoration(labelText: 'Reason'),
                              onChanged: (v) => reason = v),
                          if (error != null) Text(error!),
                        ]),
                    actions: [
                      TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (reason.trim().length < 3) {
                                    update(() => error = 'Enter a reason.');
                                    return;
                                  }
                                  update(() => saving = true);
                                  try {
                                    await widget.service.setBlocked(
                                        account['user_id'] as String,
                                        blocked,
                                        reason.trim());
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext, true);
                                    }
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      update(() {
                                        error =
                                            'Could not update access. Please retry.';
                                        saving = false;
                                      });
                                    }
                                  }
                                },
                          child: Text(saving ? 'Saving…' : 'Confirm'))
                    ]),),
                    );
    if (changed == true) await _load();
  }

  void _details(Map<String, dynamic> account) {
    final future = widget.service.details(account['user_id'] as String);
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(account['email'] as String? ?? 'Customer'),
                content: SizedBox(
                    width: 650,
                    height: 560,
                    child: FutureBuilder<Map<String, dynamic>>(
                        future: future,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                                'Could not load customer billing details.');
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final payments = snapshot.data!['payments'] as List;
                          final audit = snapshot.data!['audit'] as List;
                          return ListView(children: [
                            Text('User ID: ${account['user_id']}'),
                            Text('Name: ${account['display_name'] ?? '-'}'),
                            Text(
                                'Business: ${account['business_name'] ?? '-'}'),
                            Text(
                                'Registered: ${_date(account['registered_at'])}'),
                            Text(
                                'Email confirmed: ${_date(account['email_confirmed_at'])}'),
                            Text(
                                'Last sign-in: ${_date(account['last_sign_in_at'])}'),
                            Text(
                                'Status: ${account['membership_status']} | Paid until: ${_date(account['paid_until'])}'),
                            Text(
                                'Admin block: ${account['admin_blocked'] == true ? 'Yes' : 'No'} | Payment review: ${account['suspended'] == true ? 'Yes' : 'No'}'),
                            const Divider(height: 32),
                            const Text('Payment history',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            if (payments.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('No payments recorded.')),
                            for (final item in payments)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      'AED ${((item['amount_cents'] as num) / 100).toStringAsFixed(2)} · ${item['status']}'),
                                  subtitle: Text(
                                      '${item['billing_cycle']} · ${item['payment_source']} · ${item['mode']}\n${_date(item['paid_at'] ?? item['created_at'])}\nReference: ${item['payment_reference'] ?? item['transaction_id'] ?? '-'}${item['notes'] == null ? '' : '\n${item['notes']}'}')),
                            const Divider(height: 32),
                            const Text('Audit history',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            for (final item in audit)
                              ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(item['action'] as String),
                                  subtitle: Text(
                                      '${_date(item['created_at'])} · actor ${item['actor_user_id'] ?? 'verified payment/server'}'),
                                  children: [
                                    SelectableText(
                                        const JsonEncoder.withIndent('  ')
                                            .convert(item['details']))
                                  ]),
                          ]);
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _accounts
        .where((a) => _filter == 'all' || a['membership_status'] == _filter)
        .toList();
    return Scaffold(
        appBar:
            AppBar(title: const Text('Customers & subscriptions'), actions: [
          IconButton(
              tooltip: 'Refresh accounts',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('Customer identity, payment history and membership access',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text(
              'Verified Paymob payments update access automatically. Record bank/cash payments manually only after checking payment proof.'),
          const SizedBox(height: 20),
          Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 340,
                    child: TextField(
                        controller: _search,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                            labelText: 'Search email, name or business',
                            suffixIcon: IconButton(
                                onPressed: _busy ? null : _load,
                                icon: const Icon(Icons.search))))),
                DropdownButton<String>(
                    value: _filter,
                    items: [
                      for (final value in [
                        'all',
                        'trial',
                        'paid',
                        'unpaid',
                        'blocked',
                        'not_configured'
                      ])
                        DropdownMenuItem(
                            value: value,
                            child: Text(value.replaceAll('_', ' ')))
                    ],
                    onChanged: (v) => setState(() => _filter = v!)),
              ]),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Text(
              '${rows.length} accounts shown (up to 500 search results). Status refreshes every 30 seconds.'),
          const SizedBox(height: 16),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: [
                for (final label in [
                  'Customer',
                  'Business',
                  'Status',
                  'Cycle',
                  'Trial ends',
                  'Paid until',
                  'Actions'
                ])
                  DataColumn(label: Text(label))
              ], rows: [
                for (final account in rows)
                  DataRow(cells: [
                    DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account['email'] as String? ?? '-'),
                          Text(account['display_name'] as String? ?? '',
                              style: const TextStyle(fontSize: 12))
                        ])),
                    DataCell(Text(account['business_name'] as String? ?? '-')),
                    DataCell(Chip(
                        label: Text(account['membership_status'] as String))),
                    DataCell(Text(account['billing_cycle'] as String? ?? '-')),
                    DataCell(Text(_date(account['trial_ends_at']))),
                    DataCell(Text(_date(account['paid_until']))),
                    DataCell(Row(children: [
                      TextButton(
                          onPressed: () => _details(account),
                          child: const Text('Details')),
                      TextButton(
                          onPressed: () => _payment(account),
                          child: const Text('Record payment')),
                      TextButton(
                          onPressed: () => _block(account),
                          child: Text(account['admin_blocked'] == true
                              ? 'Remove block'
                              : 'Block'))
                    ])),
                  ])
              ])),
        ]));
  }
}

class _ManualPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  final BillingAdminService service;
  const _ManualPaymentDialog({required this.account, required this.service});
  @override
  State<_ManualPaymentDialog> createState() => _ManualPaymentDialogState();
}

class _ManualPaymentDialogState extends State<_ManualPaymentDialog> {
  final _form = GlobalKey<FormState>();
  String _cycle = 'monthly', _amount = '50.00', _reference = '', _notes = '';
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.account['billing_cycle'] == 'annual') {
      _cycle = 'annual';
      _amount = '540.00';
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.service.recordPayment(
          userId: widget.account['user_id'] as String,
          cycle: _cycle,
          amountCents: BillingAdminService.parseAmount(_amount),
          reference: _reference.trim(),
          notes: _notes.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Payment was not recorded. Check the reference, amount and account setup, then retry with the same reference.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Record a verified manual payment'),
          content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.account['email'] as String? ??
                                'Customer'),
                            const SizedBox(height: 12),
                            const Text(
                                'This records money already received, extends access and removes access blocks. It does not charge the customer.'),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                                initialValue: _cycle,
                                decoration: const InputDecoration(
                                    labelText: 'Billing cycle'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'monthly', child: Text('Monthly')),
                                  DropdownMenuItem(
                                      value: 'annual', child: Text('Annual'))
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() {
                                          _cycle = v!;
                                          _amount = _cycle == 'annual'
                                              ? '540.00'
                                              : '50.00';
                                        })),
                            const SizedBox(height: 16),
                            TextFormField(
                                key: ValueKey(_cycle),
                                initialValue: _amount,
                                enabled: !_busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText:
                                        'Total received (AED), including charges'),
                                onChanged: (v) => _amount = v,
                                validator: (v) {
                                  try {
                                    final amount =
                                        BillingAdminService.parseAmount(
                                            v ?? '');
                                    return amount <
                                            (_cycle == 'annual' ? 54000 : 5000)
                                        ? 'Amount is below the plan price.'
                                        : null;
                                  } catch (_) {
                                    return 'Enter a valid AED amount (up to 2 decimals).';
                                  }
                                }),
                            const SizedBox(height: 16),
                            TextFormField(
                                enabled: !_busy,
                                maxLength: 120,
                                decoration: const InputDecoration(
                                    labelText: 'Unique bank/receipt reference'),
                                onChanged: (v) => _reference = v,
                                validator: (v) => (v?.trim().length ?? 0) < 3
                                    ? 'Enter a payment reference.'
                                    : null),
                            TextFormField(
                                enabled: !_busy,
                                maxLength: 1000,
                                decoration: const InputDecoration(
                                    labelText: 'Internal notes (optional)'),
                                onChanged: (v) => _notes = v),
                            if (_error != null) Text(_error!),
                          ])))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Record payment & activate'))
          ]);
}
