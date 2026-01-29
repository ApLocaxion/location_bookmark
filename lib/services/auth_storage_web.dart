import 'dart:html' as html;

class AuthStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _idTokenKey = 'auth_id_token';

  static Future<void> saveAccessToken(String token) async {
    _setValue(_accessTokenKey, token);
  }

  static Future<void> saveIdToken(String token) async {
    _setValue(_idTokenKey, token);
  }

  static Future<String?> readAccessToken() async {
    return _getValue(_accessTokenKey);
  }

  static Future<String?> readIdToken() async {
    return _getValue(_idTokenKey);
  }

  static Future<void> clearAccessToken() async {
    _removeValue(_accessTokenKey);
  }

  static Future<void> clearIdToken() async {
    _removeValue(_idTokenKey);
  }

  static String? _getValue(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  static void _setValue(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Ignore storage failures (e.g., disabled or blocked).
    }
  }

  static void _removeValue(String key) {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {
      // Ignore storage failures (e.g., disabled or blocked).
    }
  }
}
