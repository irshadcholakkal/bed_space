import 'package:shared_preferences/shared_preferences.dart';

/// A Google token is reusable only for its signed-in account and must still be
/// validated with Google before opening the workspace.
class GoogleTokenStore {
  static String _key(String userId) => 'bedspace_google_session_$userId';
  static Future<void> save(String userId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), token);
  }

  static Future<String?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(userId));
  }

  static Future<void> saveRefreshToken(String userId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_key(userId)}_refresh', token);
  }

  static Future<String?> readRefreshToken(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_key(userId)}_refresh');
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
    await prefs.remove('${_key(userId)}_refresh');
  }
}
