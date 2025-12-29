/// Sheet Repository
/// Handles local sheet ID storage and retrieval
/// 
/// IMPORTANT DISCLAIMER:
/// This repository stores sheet ID locally per device.
/// No global synchronization across devices is possible.
/// 
/// This app:
/// - Is client-only
/// - Does not guarantee uniqueness across devices
/// - Is not suitable for high-security financial data
/// - Is designed for internal / prototype usage

import 'package:shared_preferences/shared_preferences.dart';

class SheetRepository {
  static const String _sheetIdKey = 'sheet_id';
  static const String _userEmailKey = 'user_email';
  static const String _accessTokenKey = 'access_token';

    Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// Save sheet ID for current user
  Future<void> saveSheetId(String sheetId, String userEmail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetIdKey, sheetId);
    await prefs.setString(_userEmailKey, userEmail);
  }

  /// Get saved sheet ID
  Future<String?> getSheetId() async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sheetIdKey);
    await prefs.remove(_userEmailKey);
  }

  /// Check if sheet ID matches current user email
  Future<bool> isSheetIdForUser(String userEmail) async {
    final savedEmail = await getUserEmail();
    return savedEmail == userEmail;
  }
}

