import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_callback_error.dart';

class SaasService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publicKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get configured => url.isNotEmpty && publicKey.isNotEmpty;
  static SupabaseClient get client => Supabase.instance.client;
  static String? get userId => configured ? client.auth.currentUser?.id : null;
  static String? startupAuthError;
  static String get authRedirectUrl => callbackFor(Uri.base).toString();
  static Uri callbackFor(Uri page) => page.resolve(
      page.path == '/app' || page.path.startsWith('/app/') ? '/app/' : '/');

  static Future<void> initialize() async {
    // Capture before the SDK consumes/clears OAuth URL parameters.
    startupAuthError = authCallbackError(Uri.base);
    if (configured) {
      await Supabase.initialize(
          url: url,
          publishableKey: publicKey,
          authOptions: const FlutterAuthClientOptions(
              persistSession: true, autoRefreshToken: true));
    }
  }
}
