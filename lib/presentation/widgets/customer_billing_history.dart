import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/saas_service.dart';
import '../../data/services/subscription_service.dart';

class CustomerBillingHistory extends StatefulWidget {
  final AccountAccess? access;
  const CustomerBillingHistory({super.key, this.access});
  @override
  State<CustomerBillingHistory> createState() => _CustomerBillingHistoryState();
}

class _CustomerBillingHistoryState extends State<CustomerBillingHistory> {
  late Future<Map<String, dynamic>> _data = _load();
  Future<Map<String, dynamic>> _load() async {
    if (!SaasService.configured || SaasService.userId == null) {
      return {'profile': null, 'payments': []};
    }
    final profile = await SaasService.client
        .from('profiles')
        .select('display_name,business_name')
        .eq('user_id', SaasService.userId!)
        .maybeSingle();
    final payments = await SaasService.client.rpc('my_payment_history');
    return {'profile': profile, 'payments': payments};
  }

  @override
  Widget build(BuildContext context) {
    if (!SaasService.configured || SaasService.userId == null) {
      return const SizedBox();
    }
    final access = widget.access;
    final status = access == null
        ? 'Checking'
        : access.suspended
            ? 'Blocked'
            : access.paidUntil != null &&
                    access.paidUntil!.isAfter(access.serverNow)
                ? 'Paid'
                : access.allowed
                    ? 'Free trial'
                    : 'Unpaid';
    return ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) setState(() => _data = _load());
        },
        title: const Text('Account & payment history'),
        subtitle: Text('Membership: $status'),
        children: [
          FutureBuilder<Map<String, dynamic>>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Payment history could not be loaded. Please try again later.'));
                }
                if (!snapshot.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator());
                }
                final profile = snapshot.data!['profile'] as Map?;
                final payments = snapshot.data!['payments'] as List;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                          title: Text(profile?['display_name'] as String? ??
                              'Your account'),
                          subtitle: Text(
                              '${SaasService.client.auth.currentUser?.email ?? ''}\n${profile?['business_name'] ?? ''}')),
                      if (payments.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No payments recorded yet.')),
                      for (final item in payments)
                        ListTile(
                            title: Text(
                                'AED ${((item['amount_cents'] as num) / 100).toStringAsFixed(2)} · ${item['status']}'),
                            subtitle: Text(
                                '${item['billing_cycle']} · ${item['payment_source']}\n${DateFormat('dd MMM yyyy').format(DateTime.parse(item['paid_at'] ?? item['created_at']).toLocal())}${item['mode'] == 'test' ? ' · Test payment' : ''}')),
                    ]);
              }),
        ]);
  }
}
