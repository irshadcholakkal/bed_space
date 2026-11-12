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
    if (SaasService.configured) {
      // Supabase refreshes its own JWT, but not Google's provider token.
      final session = SaasService.client.auth.currentSession;
      if (session == null) return null;
      final refreshToken = session.providerRefreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await GoogleTokenStore.saveRefreshToken(session.user.id, refreshToken);
      }
      final candidates = <String>{
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
        final response = await SaasService.client.functions.invoke(
            'refresh-google-session',
            body: {'refresh_token': savedRefresh});
        final result = response.data as Map<String, dynamic>;
        final token = result['access_token'] as String?;
        if (token == null ||
            SaasService.userId != session.user.id ||
            !await _validGoogleToken(token, session.user.email)) {
          return null;
        }
        await GoogleTokenStore.save(session.user.id, token);
        final rotated = result['refresh_token'] as String?;
        if (rotated != null && rotated.isNotEmpty) {
          await GoogleTokenStore.saveRefreshToken(session.user.id, rotated);
        }
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

  Future<bool> _validGoogleToken(String token, String? email) async {
    try {
      final response = await http
          .get(Uri.https(
              'oauth2.googleapis.com', '/tokeninfo', {'access_token': token}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final info = jsonDecode(response.body) as Map<String, dynamic>;
      final scopes = (info['scope'] as String? ?? '').split(' ');
      return _scopes.skip(3).every(scopes.contains) &&
          email != null &&
          info['email'] == email &&
          (int.tryParse('${info['expires_in']}') ?? 0) > 60;
    } catch (_) {
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (SaasService.configured) {
      final userId = SaasService.userId;
      await SaasService.client.auth.signOut();
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
