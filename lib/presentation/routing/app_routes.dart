import 'package:shared_preferences/shared_preferences.dart';

class AppRoutes {
  static const dashboard = '/dashboard';
  static const pages = <String>{
    dashboard,
    '/rooms',
    '/financials',
    '/financials/tenants',
    '/rooms/occupancy',
    '/settings',
    '/buildings',
    '/rooms/manage',
    '/tenants',
    '/vacant-beds',
    '/billing',
    '/admin',
    '/connect-google',
  };

  static String? safeDestination(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//')) {
      return null;
    }
    if (pages.contains(uri.path) ||
        RegExp(r'^/rooms/[^/]+/expenses$').hasMatch(uri.path) ||
        RegExp(r'^/tenants/[^/]+/rent-balance$').hasMatch(uri.path)) {
      return uri
          .path; // Never retain OAuth codes, fragments or arbitrary queries.
    }
    return null;
  }
}

/// Retains only a safe internal path while Google temporarily leaves the app.
class AppRouteIntent {
  static const _key = 'bedspace_post_auth_path';
  static String? _path;
  static Future<void> restore() async {
    try {
      _path = AppRoutes.safeDestination(
          (await SharedPreferences.getInstance()).getString(_key));
    } catch (_) {
      _path = null;
    }
  }

  static Future<void> save(String? value) async {
    _path = AppRoutes.safeDestination(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_path == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, _path!);
      }
    } catch (_) {/* Navigation preferences must not prevent sign-in. */}
  }

  static String? take() {
    final path = _path;
    _path = null;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.remove(_key))
        .catchError((Object _) => false);
    return path;
  }
}
