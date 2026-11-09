/// Customer-scoped spreadsheet references and short-lived Google session tokens.
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../services/saas_service.dart';

class SheetRepository {
  final String? _ownerId = SaasService.userId;
  static final Map<String, String> _sessionTokens = {};
  static void clearSessionTokens() => _sessionTokens.clear();
  String get _prefix => _ownerId == null ? '' : '${_ownerId}_';
  String get _sheetIdKey => '${_prefix}sheet_id';
  String get _userEmailKey => '${_prefix}user_email';
  String get _accessTokenKey => '${_prefix}access_token';

  Future<void> saveToken(String token) async {
    if (SaasService.configured) {
      _sessionTokens[_prefix] = token;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<String?> getToken() async {
    if (SaasService.configured) return _sessionTokens[_prefix];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// Save sheet ID for current user
  Future<void> saveSheetId(String sheetId, String userEmail,
      {String? driveFolderId}) async {
    if (_ownerId != null) {
      await SaasService.client.from('storage_bindings').upsert({
        'user_id': _ownerId,
        'google_email': userEmail,
        'spreadsheet_id': sheetId,
        if (driveFolderId != null) 'drive_folder_id': driveFolderId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetIdKey, sheetId);
    await prefs.setString(_userEmailKey, userEmail);
  }

  /// Get saved sheet ID
  Future<String?> getSheetId() async {
    if (_ownerId != null) {
      final binding = await SaasService.client
          .from('storage_bindings')
          .select('spreadsheet_id, google_email')
          .eq('user_id', _ownerId!)
          .maybeSingle();
      if (binding != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sheetIdKey, binding['spreadsheet_id'] as String);
        await prefs.setString(_userEmailKey, binding['google_email'] as String);
        return binding['spreadsheet_id'] as String;
      }
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sheetIdKey);
  }

  /// Get saved user email
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Clear saved sheet ID (for reset functionality)
  Future<void> clearSheetId() async {
    _sessionTokens.remove(_prefix);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sheetIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_accessTokenKey);
  }

  /// Check if sheet ID matches current user email
  Future<bool> isSheetIdForUser(String userEmail) async {
    final savedEmail = await getUserEmail();
    return savedEmail == userEmail;
  }
}
