import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _idTokenKey = 'auth_id_token';

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  static Future<void> saveIdToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idTokenKey, token);
  }

  static Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> readIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_idTokenKey);
  }

  static Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
  }

  static Future<void> clearIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idTokenKey);
  }
}
