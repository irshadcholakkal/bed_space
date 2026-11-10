import 'saas_service.dart';

class BillingAdminService {
  const BillingAdminService();
  static int parseAmount(String input) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(input.trim())) {
      throw const FormatException('Invalid amount');
    }
    final parts = input.trim().split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  }

  Future<bool> isAdmin() async =>
      SaasService.configured &&
      SaasService.userId != null &&
      await SaasService.client.rpc('is_billing_admin') == true;
  Future<List<Map<String, dynamic>>> accounts(String search) async {
    final data = await SaasService.client.rpc('admin_billing_accounts',
        params: {'p_search': search, 'p_limit': 500});
    return (data as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<Map<String, dynamic>> details(String userId) async =>
      Map<String, dynamic>.from(await SaasService.client
          .rpc('admin_customer_billing', params: {'p_user_id': userId}) as Map);
  Future<void> recordPayment(
      {required String userId,
      required String cycle,
      required int amountCents,
      required String reference,
      required String notes}) async {
    await SaasService.client.rpc('admin_record_payment', params: {
      'p_user_id': userId,
      'p_billing_cycle': cycle,
      'p_amount_cents': amountCents,
      'p_reference': reference,
      'p_notes': notes
    });
  }

  Future<void> setBlocked(String userId, bool blocked, String reason) async {
    await SaasService.client.rpc('admin_set_membership_block', params: {
      'p_user_id': userId,
      'p_blocked': blocked,
      'p_reason': reason
    });
  }
}
