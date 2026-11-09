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

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Check if user is signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get current user account
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  /// Get current access token
  Future<String?> getAccessToken() async {
    final GoogleSignInAccount? account = _googleSignIn.currentUser;
    if (account == null) return null;

    final GoogleSignInAuthentication auth = await account.authentication;
    return auth.accessToken;
  }

  /// Get current user email
  Future<String?> getCurrentUserEmail() async {
    final account = await getCurrentUser();
    return account?.email;
  }
}
