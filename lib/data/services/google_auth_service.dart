/// Google Sign-In Authentication Service
///
/// IMPORTANT DISCLAIMER:
/// This service provides client-only authentication.
/// No backend validation is performed.
/// Suitable for internal/personal use only.
///
/// This app:
/// - Is client-only
/// - Does not guarantee uniqueness across devices
/// - Is not suitable for high-security financial data
/// - Is designed for internal / prototype usage
library;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'saas_service.dart';
import 'google_token_store.dart';

class GoogleAuthService {
  GoogleAuthService({http.Client? httpClient}) : _httpClient = httpClient;
  final http.Client? _httpClient;
  String? connectionError;
  String? get accountUserId => SaasService.userId;
  static final Map<String, Future<String?>> _renewals = {};
  static final Map<String, (String, DateTime)> _validated = {};
  static const List<String> _scopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: const String.fromEnvironment('GOOGLE_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_CLIENT_ID'),
    scopes: _scopes,
  );

  /// Sign in with Google
  /// Returns access token for Google Sheets API
  Future<String?> signIn() async {
    if (SaasService.configured) {
      const callback = String.fromEnvironment('SUPABASE_AUTH_REDIRECT_URL');
      if (!kIsWeb && callback.isEmpty) {
        throw StateError('Configure SUPABASE_AUTH_REDIRECT_URL for this app.');
      }
      final launched = await SaasService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? SaasService.authRedirectUrl : callback,
        scopes: _scopes.join(' '),
        queryParams: const {'prompt': 'consent', 'access_type': 'offline'},
      );
      if (!launched) throw StateError('Could not open Google sign-in.');
      return null; // Completion arrives through the Supabase auth callback.
    }
    if (kIsWeb && const String.fromEnvironment('GOOGLE_CLIENT_ID').isEmpty) {
      throw StateError('Google sign-in is not configured. Set GOOGLE_CLIENT_ID '
          'in Cloudflare Pages Environment Variables to your web OAuth client ID, then redeploy.');
    }
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  /// Attempt silent sign-in (no UI). Returns access token if successful.
  Future<String?> signInSilently() async {
    connectionError = null;
    final owner = accountUserId;
    if (SaasService.configured && owner != null) {
      return _renewals.putIfAbsent(
          owner,
          () => _restoreGoogleSession()
              .timeout(const Duration(seconds: 30), onTimeout: () => null)
              .whenComplete(() => _renewals.remove(owner)));
    }
    return _restoreGoogleSession()
        .timeout(const Duration(seconds: 30), onTimeout: () => null);
  }

  Future<String?> _restoreGoogleSession() async {
    if (SaasService.configured) {
      // Supabase refreshes its own JWT, but not Google's provider token.
      final session = SaasService.client.auth.currentSession;
      if (session == null) return null;
      final refreshToken = session.providerRefreshToken;
      if (refreshToken != null &&
          refreshToken.isNotEmpty &&
          await GoogleTokenStore.readRefreshToken(session.user.id) == null) {
        await GoogleTokenStore.saveRefreshToken(session.user.id, refreshToken);
      }
      final candidates = <String>{
        // The callback token contains the permissions just granted by Google.
        // Do not spend the restoration deadline checking an expired cache first.
        if (session.providerToken?.isNotEmpty == true) session.providerToken!,
        if (await GoogleTokenStore.read(session.user.id)
            case final String cached)
          cached,
      };
      for (final token in candidates) {
        if (await _validGoogleToken(token, session.user.email)) {
          if (SaasService.userId != session.user.id) return null;
          await GoogleTokenStore.save(session.user.id, token);
          return token;
        }
      }
      final savedRefresh =
          await GoogleTokenStore.readRefreshToken(session.user.id);
      if (savedRefresh == null || savedRefresh.isEmpty) return null;
      try {
        if (session.isExpired) await SaasService.client.auth.refreshSession();
        if (SaasService.userId != session.user.id) return null;
        final response = await SaasService.client.functions.invoke(
            'refresh-google-session',
            body: {'refresh_token': savedRefresh});
        final result = response.data as Map<String, dynamic>;
        final token = result['access_token'] as String?;
        if (token == null || SaasService.userId != session.user.id) {
          return null;
        }
        final rotated = result['refresh_token'] as String?;
        if (rotated != null && rotated.isNotEmpty) {
          await GoogleTokenStore.saveRefreshToken(session.user.id, rotated);
        }
        if (!await _validGoogleToken(token, session.user.email) ||
            SaasService.userId != session.user.id) {
          return null;
        }
        await GoogleTokenStore.save(session.user.id, token);
        return token;
      } catch (_) {
        // Keep the app's account session. Only Google may need reconnecting.
        return null;
      }
    }
    if (kIsWeb && const String.fromEnvironment('GOOGLE_CLIENT_ID').isEmpty) {
      return null;
    }
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _validGoogleToken(String token, String? email) =>
      validateGoogleToken(token, email);

  @visibleForTesting
  Future<bool> validateGoogleToken(String token, String? email) async {
    final cached = email == null ? null : _validated[email];
    if (cached != null &&
        cached.$1 == token &&
        DateTime.now().isBefore(cached.$2)) {
      return true;
    }
    try {
      final uri = Uri.https(
          'oauth2.googleapis.com', '/tokeninfo', {'access_token': token});
      final response = await (_httpClient?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        connectionError =
            'Google access has expired or was revoked. Reconnect Google. Reference: GOOGLE_TOKEN';
        return false;
      }
      final info = jsonDecode(response.body) as Map<String, dynamic>;
      final scopes = (info['scope'] as String? ?? '').split(' ');
      final valid = _scopes.skip(3).every(scopes.contains) &&
          email != null &&
          (info['email'] as String?)?.trim().toLowerCase() ==
              email.trim().toLowerCase() &&
          (int.tryParse('${info['expires_in']}') ?? 0) > 60;
      if (valid) {
        connectionError = null;
        _validated[email] = (
          token,
          DateTime.now().add(Duration(
              seconds: (int.tryParse('${info['expires_in']}') ?? 0) - 60))
        );
      } else if (!_scopes.skip(3).every(scopes.contains)) {
        connectionError =
            'Google did not grant both Sheets and Drive permissions. Reconnect Google and select both permissions on the consent screen. Reference: GOOGLE_SCOPES';
      } else if (email == null ||
          (info['email'] as String?)?.trim().toLowerCase() !=
              email.trim().toLowerCase()) {
        connectionError =
            'Connect the same Google email used to sign in to this account. Reference: GOOGLE_ACCOUNT';
      } else {
        connectionError =
            'Google access has expired. Reconnect Google. Reference: GOOGLE_TOKEN';
      }
      return valid;
    } catch (_) {
      connectionError =
          'Could not verify Google permissions. Check your connection and retry. Reference: GOOGLE_VERIFY';
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (SaasService.configured) {
      final userId = SaasService.userId;
      await SaasService.client.auth.signOut();
      _validated.clear();
      if (userId != null) await GoogleTokenStore.clear(userId);
      return;
    }
    await _googleSignIn.signOut();
  }

  /// Check if user is signed in
  Future<bool> isSignedIn() async {
    if (SaasService.configured) return SaasService.userId != null;
    return await _googleSignIn.isSignedIn();
  }

  /// Get current user account
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  /// Get current access token
  Future<String?> getAccessToken() async {
    if (SaasService.configured) return signInSilently();
    final GoogleSignInAccount? account = _googleSignIn.currentUser;
    if (account == null) return null;

    final GoogleSignInAuthentication auth = await account.authentication;
    return auth.accessToken;
  }

  /// Get current user email
  Future<String?> getCurrentUserEmail() async {
    if (SaasService.configured) {
      return SaasService.client.auth.currentUser?.email;
    }
    final account = await getCurrentUser();
    return account?.email;
  }
}
