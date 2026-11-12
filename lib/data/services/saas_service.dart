import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'auth_callback_error.dart';
import 'google_token_store.dart';
import '../../presentation/routing/app_routes.dart';

class SaasService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publicKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get configured => url.isNotEmpty && publicKey.isNotEmpty;
  static SupabaseClient get client => Supabase.instance.client;
  static String? get userId => configured ? client.auth.currentUser?.id : null;
  static String? startupAuthError;
  static StreamSubscription<dynamic>? _googleSessionSubscription;
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
      await _rememberGoogleTokens(client.auth.currentSession);
      await AppSessionRoute.restore(userId);
      await _googleSessionSubscription?.cancel();
      _googleSessionSubscription =
          client.auth.onAuthStateChange.listen((state) {
        unawaited(_rememberGoogleTokens(state.session));
        unawaited(AppSessionRoute.restore(state.session?.user.id));
      }, onError: (Object _) {});
    }
  }

  static Future<void> _rememberGoogleTokens(Session? session) async {
    if (session == null) return;
    try {
      if (session.providerToken?.isNotEmpty == true) {
        await GoogleTokenStore.save(session.user.id, session.providerToken!);
      }
      if (session.providerRefreshToken?.isNotEmpty == true) {
        await GoogleTokenStore.saveRefreshToken(
            session.user.id, session.providerRefreshToken!);
      }
    } catch (_) {
      // A storage failure must not discard an otherwise valid account session.
    }
  }
}
