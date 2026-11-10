import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/saas_service.dart';
import '../../data/services/subscription_service.dart';
import '../widgets/customer_billing_history.dart';

class BillingScreen extends StatefulWidget {
  final AccountAccess? access;
  final VoidCallback? onRefresh;
  const BillingScreen({super.key, this.access, this.onRefresh});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(),
      _last = TextEditingController(),
      _phone = TextEditingController();
  bool _annual = false, _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _annual = widget.access?.billingCycle == 'annual';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await SaasService.client.functions
          .invoke('create-paymob-checkout', body: {
        'billing_cycle': _annual ? 'annual' : 'monthly',
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'phone': _phone.text.trim(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['error'] != null) throw StateError(data['error'].toString());
      final url = Uri.parse(data['url'] as String);
      if (url.scheme != 'https' ||
          ![
            'uae.paymob.com',
            'accept.paymob.com',
            'ksa.paymob.com',
            'oman.paymob.com'
          ].contains(url.host)) {
        throw StateError('Invalid payment link');
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(data['mode'] == 'test'
                    ? 'Paymob test payment'
                    : 'Review your payment'),
                content: Text(
                    'Total: AED ${((data['amount_cents'] as num) / 100).toStringAsFixed(2)}\nIncludes the plan price and configured other charges.\n\n${_annual ? 'One year' : 'One month'} of access will be added after payment confirmation.${data['mode'] == 'test' ? '\nTest mode: use Paymob test credentials only.' : ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Continue to Paymob'))
                ],
              ));
      if (confirmed == true &&
          !await launchUrl(url,
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_self')) {
        throw StateError('Could not open the payment page');
      }
    } on FunctionException catch (e) {
      if (mounted) {
        setState(() => _message = e.details is Map
            ? e.details['error']?.toString() ??
                'Payment is unavailable. Please try later.'
            : 'Payment is unavailable. Please try later.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Could not start payment. Please try again or contact support.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    return Scaffold(
      backgroundColor: const Color(0xfff5f6f3),
      appBar: AppBar(title: const Text('Your Bedspace membership')),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Form(
                              key: _form,
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        access?.allowed == true
                                            ? 'Keep your space in sync.'
                                            : 'Your workspace is paused.',
                                        style: const TextStyle(
                                            fontFamily: 'HedvigLetters',
                                            fontSize: 34)),
                                    const SizedBox(height: 16),
                                    Text(
                                        access?.suspended == true
                                            ? 'Your account needs a payment review. Contact support before making another payment.'
                                            : access?.allowed == true
                                                ? 'Access is available until ${DateFormat('dd MMM yyyy').format(access!.accessUntil.toLocal())}. Payments add time after your current trial or paid period.'
                                                : 'Your trial or paid period has ended. Renew your membership to reopen your workspace. Your Google files remain in your account.',
                                        style: const TextStyle(height: 1.7)),
                                    const SizedBox(height: 24),
                                    SegmentedButton<bool>(
                                        segments: const [
                                          ButtonSegment(
                                              value: false,
                                              label: Text('Monthly')),
                                          ButtonSegment(
                                              value: true,
                                              label: Text('Annual · −10%'))
                                        ],
                                        selected: {
                                          _annual
                                        },
                                        onSelectionChanged: _busy
                                            ? null
                                            : (s) => setState(
                                                () => _annual = s.first)),
                                    const SizedBox(height: 22),
                                    Text(
                                        _annual
                                            ? 'AED 540/year'
                                            : 'AED 50/month',
                                        style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w600)),
                                    const Text(
                                        '+ other charges. You will review the total before payment.'),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                        controller: _first,
                                        enabled: !_busy,
                                        decoration: const InputDecoration(
                                            labelText: 'First name'),
                                        validator: (v) =>
                                            (v?.trim().isEmpty ?? true)
                                                ? 'Enter your first name'
                                                : null),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        controller: _last,
                                        enabled: !_busy,
                                        decoration: const InputDecoration(
                                            labelText: 'Last name'),
                                        validator: (v) =>
                                            (v?.trim().isEmpty ?? true)
                                                ? 'Enter your last name'
                                                : null),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        controller: _phone,
                                        enabled: !_busy,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Phone with country code',
                                            hintText: '+971…'),
                                        validator: (v) => RegExp(
                                                    r'^\+[1-9]\d{7,14}$')
                                                .hasMatch(v?.trim() ?? '')
                                            ? null
                                            : 'Enter your international phone number'),
                                    const SizedBox(height: 24),
                                    if (_message != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 16),
                                          child: Semantics(
                                              liveRegion: true,
                                              child: Text(_message!))),
                                    FilledButton(
                                        onPressed:
                                            _busy || access?.suspended == true
                                                ? null
                                                : _checkout,
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(_busy
                                                ? 'Preparing payment…'
                                                : 'Continue to payment'))),
                                    if (widget.onRefresh != null)
                                      TextButton(
                                          onPressed:
                                              _busy ? null : widget.onRefresh,
                                          child: const Text(
                                              'Already paid? Check payment status')),
                                    const SizedBox(height: 12),
                                    CustomerBillingHistory(access: access),
                                    const Text(
                                        'Payment is confirmed securely by Paymob. Returning from checkout alone does not activate your membership.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12, height: 1.7)),
                                    if (widget.onRefresh != null)
                                      TextButton(
                                          onPressed: () =>
                                              SaasService.client.auth.signOut(),
                                          child: const Text('Sign out')),
                                  ]))))))),
    );
  }
}
