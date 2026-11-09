import 'package:supabase_flutter/supabase_flutter.dart';

class SaasService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publicKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get configured => url.isNotEmpty && publicKey.isNotEmpty;
  static SupabaseClient get client => Supabase.instance.client;
  static String? get userId => configured ? client.auth.currentUser?.id : null;

  static Future<void> initialize() async {
    if (configured) await Supabase.initialize(url: url, publishableKey: publicKey);
  }
}
