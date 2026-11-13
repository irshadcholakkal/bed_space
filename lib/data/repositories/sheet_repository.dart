/// Customer-scoped spreadsheet references and short-lived Google session tokens.
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../services/saas_service.dart';
import '../services/offline_status.dart';
import '../services/google_auth_service.dart';

class SheetRepository {
  final String? _ownerId = SaasService.userId;
  static final Map<String, String> _sessionTokens = {};
  static void clearSessionTokens() => _sessionTokens.clear();
  String get _prefix => _ownerId == null ? '' : '${_ownerId}_';
  String get _sheetIdKey => '${_prefix}sheet_id';
  String get _userEmailKey => '${_prefix}user_email';
  String get _accessTokenKey => '${_prefix}access_token';
  String get _driveFolderKey => '${_prefix}drive_folder_id';

  Future<void> saveToken(String token) async {
    if (SaasService.configured) {
      _sessionTokens[_prefix] = token;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<String?> getToken() async {
    if (SaasService.configured) {
      if (_ownerId == null || _ownerId != SaasService.userId) return null;
      final token = await GoogleAuthService().signInSilently();
      if (_ownerId != SaasService.userId) return null;
      if (token != null) _sessionTokens[_prefix] = token;
      return token;
    }
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
    if (driveFolderId == null &&
        (prefs.getString(_sheetIdKey) != sheetId ||
            prefs.getString(_userEmailKey) != userEmail)) {
      await prefs.remove(_driveFolderKey);
    }
    await prefs.setString(_sheetIdKey, sheetId);
    await prefs.setString(_userEmailKey, userEmail);
    if (driveFolderId != null) {
      await prefs.setString(_driveFolderKey, driveFolderId);
    }
  }

  /// Get saved sheet ID
  Future<String?> getSheetId() async {
    if (await isDeviceOffline()) return getCachedSheetId();
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

  Future<String?> getCachedSheetId() async =>
      (await SharedPreferences.getInstance()).getString(_sheetIdKey);

  Future<String?> getDriveFolderId() async {
    if (_ownerId != null) {
      final sheetId = await getSheetId();
      if (sheetId == null) return null;
      final binding = await SaasService.client
          .from('storage_bindings')
          .select('drive_folder_id')
          .eq('user_id', _ownerId!)
          .eq('spreadsheet_id', sheetId)
          .maybeSingle();
      return binding?['drive_folder_id'] as String?;
    }
    return (await SharedPreferences.getInstance()).getString(_driveFolderKey);
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
    await prefs.remove(_driveFolderKey);
  }

  /// Check if sheet ID matches current user email
  Future<bool> isSheetIdForUser(String userEmail) async {
    final savedEmail = await getUserEmail();
    return savedEmail == userEmail;
  }
}
