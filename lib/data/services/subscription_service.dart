import 'saas_service.dart';

class AccountAccess {
  final bool allowed, suspended;
  final DateTime serverNow, accessUntil, trialEndsAt;
  final DateTime? paidUntil;
  AccountAccess.fromJson(Map<String, dynamic> json)
      : allowed = json['allowed'] == true,
        suspended = json['suspended'] == true,
        serverNow = DateTime.parse(json['server_now'] as String),
        accessUntil = DateTime.parse(json['access_until'] as String),
        trialEndsAt = DateTime.parse(json['trial_ends_at'] as String),
        paidUntil = json['paid_until'] == null
            ? null
            : DateTime.parse(json['paid_until'] as String);
}

class SubscriptionService {
  static Future<AccountAccess> access() async {
    final result = await SaasService.client
        .rpc('account_access')
        .timeout(const Duration(seconds: 15));
    if (result is! Map<String, dynamic>) {
      throw StateError('Subscription is unavailable');
    }
    return AccountAccess.fromJson(result);
  }
}
