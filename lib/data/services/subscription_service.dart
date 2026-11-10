import 'package:supabase_flutter/supabase_flutter.dart';
import 'saas_service.dart';

class MembershipCheckFailure implements Exception {
  final String reference, message;
  const MembershipCheckFailure(this.reference, this.message);
  static const connection = MembershipCheckFailure('MEMBERSHIP_CONNECTION',
      'We could not verify your membership. Please check your connection and try again.');
  static const setup = MembershipCheckFailure('MEMBERSHIP_SETUP',
      'Membership verification is not configured yet. Please contact support.');
  static const missing = MembershipCheckFailure('MEMBERSHIP_RECORD',
      'Your membership has not been set up yet. Please contact support.');
  static const session = MembershipCheckFailure('MEMBERSHIP_SESSION',
      'Your session has expired. Please sign out and sign in again.');

  static MembershipCheckFailure fromError(Object error) {
    if (error is MembershipCheckFailure) return error;
    if (error is PostgrestException) {
      if (['PGRST202', 'PGRST205', '42P01', '42883', '42501']
          .contains(error.code)) {
        return setup;
      }
      if (['PGRST301', 'PGRST302', 'PGRST303'].contains(error.code)) {
        return session;
      }
    }
    if (error is FormatException || error is TypeError) return setup;
    return connection;
  }
}

class AccountAccess {
  final bool allowed, suspended;
  final DateTime serverNow, accessUntil, trialEndsAt;
  final DateTime? paidUntil;
  final String? billingCycle;
  AccountAccess.fromJson(Map<String, dynamic> json)
      : billingCycle = json['billing_cycle'] as String?,
        allowed = json['allowed'] == true,
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
    try {
      if (SaasService.client.auth.currentSession == null) {
        throw MembershipCheckFailure.session;
      }
      final result = await SaasService.client
          .rpc('account_access')
          .timeout(const Duration(seconds: 15));
      if (result == null) throw MembershipCheckFailure.missing;
      if (result is! Map<String, dynamic>) throw MembershipCheckFailure.setup;
      return AccountAccess.fromJson(result);
    } catch (error) {
      throw MembershipCheckFailure.fromError(error);
    }
  }
}
