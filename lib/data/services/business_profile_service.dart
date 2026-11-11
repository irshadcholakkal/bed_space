import 'package:supabase_flutter/supabase_flutter.dart';

/// Keep contact details durable even while the phone-column migration rolls out.
class BusinessProfileService {
  final SupabaseClient client;
  BusinessProfileService(this.client);

  static bool _missingPhone(PostgrestException error) =>
      ['42703', 'PGRST204'].contains(error.code) &&
      error.message.contains('phone_number');

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before loading business details.');
    }
    final metadata = user.userMetadata ?? {};
    Map<String, dynamic>? profile;
    try {
      final rows = await client
          .from('profiles')
          .select('business_name, phone_number')
          .eq('user_id', user.id)
          .limit(1);
      profile = rows.firstOrNull;
    } on PostgrestException catch (error) {
      if (!_missingPhone(error)) rethrow;
      final rows = await client
          .from('profiles')
          .select('business_name')
          .eq('user_id', user.id)
          .limit(1);
      profile = rows.firstOrNull;
    }
    return {
      for (final key in ['business_name', 'phone_number'])
        key: (metadata[key] as String?)?.isNotEmpty == true
            ? metadata[key]
            : profile?[key] ?? '',
    };
  }

  Future<void> save(
      {required String businessName, required String phoneNumber}) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before saving business details.');
    }
    final details = {
      'business_name': businessName.trim(),
      'phone_number': phoneNumber.trim()
    };
    // Auth metadata does not depend on optional profile columns and is scoped
    // to the signed-in user by Supabase Auth.
    await client.auth.updateUser(UserAttributes(data: details));
    try {
      await client.from('profiles').update(details).eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (!_missingPhone(error)) rethrow;
      await client.from('profiles').update(
          {'business_name': details['business_name']}).eq('user_id', user.id);
    }
  }

  static String errorMessage(Object error) {
    if (error is AuthException || error is StateError) {
      return 'Your session could not be verified. Please sign out and sign in again.';
    }
    if (error is PostgrestException &&
        ['42501', '42P01', 'PGRST205'].contains(error.code)) {
      return 'Business profile access is not configured. Please contact the administrator.';
    }
    return 'Could not save your business details. Check your connection and try again.';
  }
}
