class AuthStorage {
  static final Map<String, String> _cache = <String, String>{};
  static const _accessTokenKey = 'auth_access_token';
  static const _idTokenKey = 'auth_id_token';

  static Future<void> saveAccessToken(String token) async {
    _cache[_accessTokenKey] = token;
  }

  static Future<void> saveIdToken(String token) async {
    _cache[_idTokenKey] = token;
  }

  static Future<String?> readAccessToken() async {
    return _cache[_accessTokenKey];
  }

  static Future<String?> readIdToken() async {
    return _cache[_idTokenKey];
  }

  static Future<void> clearAccessToken() async {
    _cache.remove(_accessTokenKey);
  }

  static Future<void> clearIdToken() async {
    _cache.remove(_idTokenKey);
  }
}
