import 'package:shared_preferences/shared_preferences.dart';

class AppRoutes {
  static const dashboard = '/dashboard';
  static const pages = <String>{
    dashboard,
    '/rooms',
    '/financials',
    '/financials/tenants',
    '/rooms/occupancy',
    '/rooms/available',
    '/settings',
    '/buildings',
    '/rooms/manage',
    '/tenants',
    '/bookings',
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

/// Remember only workspace routes, separately for each authenticated account.
class AppSessionRoute {
  static String? _userId;
  static String? _lastRoute;
  static String? get lastRoute => _lastRoute;
  static Future<void> restore(String? userId) async {
    if (_userId == userId && userId != null) return;
    _userId = userId;
    _lastRoute = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId == null) {
        await prefs.remove('bedspace_session_user');
      } else {
        await prefs.setString('bedspace_session_user', userId);
        if (_userId == userId && _lastRoute == null) {
          _lastRoute =
              safeRoute(prefs.getString('bedspace_last_route_$userId'));
        }
      }
    } catch (_) {/* Storage availability must not change authentication. */}
  }

  static String? safeRoute(String? value) {
    final path = AppRoutes.safeDestination(value);
    if (path == null) return null;
    final uri = Uri.parse(value!);
    final parameters = <String, String>{};
    if (path == '/rooms' || path == '/financials') {
      for (final key in ['building', 'room', 'period']) {
        final data = uri.queryParameters[key];
        if (data != null && data.length <= 200) parameters[key] = data;
      }
    }
    return Uri(
            path: path, queryParameters: parameters.isEmpty ? null : parameters)
        .toString();
  }

  static Future<void> save(String? userId, String value) async {
    if (userId == null) return;
    if (_userId != userId) await restore(userId);
    final safe = safeRoute(value);
    if (safe == null || _lastRoute == safe) return;
    _lastRoute = safe;
    try {
      await (await SharedPreferences.getInstance())
          .setString('bedspace_last_route_$userId', safe);
    } catch (_) {/* Keep navigation working when storage is unavailable. */}
  }
}
