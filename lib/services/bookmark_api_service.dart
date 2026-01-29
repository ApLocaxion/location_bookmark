import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/bookmark_data.dart';
import '../services/auth_storage.dart';

class BookmarkApiService {
  static const _endpoint =
      'https://k2mvk4qe8c.execute-api.eu-north-1.amazonaws.com/prod/';
  static const _bucketName = 'bookmark-bucket-locaxion';
  static const _region = 'eu-north-1';
  static const _imageEndpoint =
      'https://k2mvk4qe8c.execute-api.eu-north-1.amazonaws.com/prod/image';

  static Future<String?> _readIdToken() async {
    final idToken = await AuthStorage.readIdToken();
    if (idToken == null) {
      if (kDebugMode) {
        debugPrint('BookmarkApiService: no id token available');
      }
      return null;
    }

    final trimmed = idToken.trim();
    if (trimmed.isEmpty) {
      if (kDebugMode) {
        debugPrint('BookmarkApiService: id token empty after trim');
      }
      return null;
    }
    return trimmed;
  }

  static Map<String, String> _buildHeaders({
    required String? idToken,
    required bool useBearer,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = useBearer ? 'Bearer $idToken' : idToken;
      if (kDebugMode) {
        final head = idToken.length >= 6 ? idToken.substring(0, 6) : idToken;
        final tail = idToken.length >= 6
            ? idToken.substring(idToken.length - 6)
            : idToken;
        debugPrint(
          'BookmarkApiService: auth token source=id length=${idToken.length} bearer=$useBearer head=$head tail=$tail',
        );
      }
    }
    return headers;
  }

  static Future<http.Response> _postWithToken({
    required Uri uri,
    required Map<String, dynamic> payload,
    required String? idToken,
    required bool useBearer,
  }) {
    return http.post(
      uri,
      headers: _buildHeaders(idToken: idToken, useBearer: useBearer),
      body: jsonEncode(payload),
    );
  }

  static Future<http.Response> _getWithToken({
    required Uri uri,
    required String? idToken,
    required bool useBearer,
  }) {
    return http.get(
      uri,
      headers: _buildHeaders(idToken: idToken, useBearer: useBearer),
    );
  }

  static Future<http.Response> _deleteWithToken({
    required Uri uri,
    required String? idToken,
    required bool useBearer,
  }) {
    return http.delete(
      uri,
      headers: _buildHeaders(idToken: idToken, useBearer: useBearer),
    );
  }

  static Future<void> saveBookmark({
    required double latitude,
    required double longitude,
    required String imageBase64,
  }) async {
    final uri = Uri.parse(_endpoint);
    final idToken = await _readIdToken();
    final payload = {'lat': latitude, 'log': longitude, 'image': imageBase64};

    var response = await _postWithToken(
      uri: uri,
      payload: payload,
      idToken: idToken,
      useBearer: false,
    );
    if (response.statusCode == 401 && idToken != null) {
      if (kDebugMode) {
        debugPrint('BookmarkApiService: retrying with Bearer token');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'API error: ${response.statusCode} ${response.reasonPhrase ?? ''} ${response.body}',
      );
    }
  }

  static Future<List<Bookmark>> fetchBookmarks() async {
    final uri = Uri.parse(_endpoint);
    final idToken = await _readIdToken();
    var response = await _getWithToken(
      uri: uri,
      idToken: idToken,
      useBearer: false,
    );
    if (response.statusCode == 401 && idToken != null) {
      if (kDebugMode) {
        debugPrint('BookmarkApiService: retrying fetch with Bearer token');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'API error: ${response.statusCode} ${response.reasonPhrase ?? ''} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final items = _extractItems(decoded);
    final bookmarks = items
        .map(_parseBookmark)
        .whereType<Bookmark>()
        .toList(growable: false);
    bookmarks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return bookmarks;
  }

  static Future<void> deleteBookmarkByUuid(String uuid) async {
    final trimmed = uuid.trim();
    if (trimmed.isEmpty) {
      throw StateError('Missing bookmark uuid for delete.');
    }
    final idToken = await _readIdToken();
    final uri = Uri.parse(
      _endpoint,
    ).replace(queryParameters: {'uuid': trimmed});
    var response = await _deleteWithToken(
      uri: uri,
      idToken: idToken,
      useBearer: false,
    );
    if (response.statusCode == 401 && idToken != null) {
      if (kDebugMode) {
        debugPrint('BookmarkApiService: retrying delete with Bearer token');
      }
      response = await _deleteWithToken(
        uri: uri,
        idToken: idToken,
        useBearer: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'API error: ${response.statusCode} ${response.reasonPhrase ?? ''} ${response.body}',
      );
    }
  }

  static List<dynamic> _extractItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final items = decoded['items'] ?? decoded['data'];
      if (items is List) return items;
    }
    return const [];
  }

  static Bookmark? _parseBookmark(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final uuid = map['uuid']?.toString();
    final lat = _toDouble(map['lat'] ?? map['latitude']);
    final log = _toDouble(
      map['log'] ?? map['lon'] ?? map['lng'] ?? map['longitude'],
    );
    if (lat == null || log == null) return null;

    final imagePath =
        map['imagePath'] ?? map['image'] ?? map['image_url'] ?? map['imageUrl'];
    final resolvedImagePath = _resolveImagePath(imagePath);
    final timestampRaw =
        map['createdAt'] ?? map['created_at'] ?? map['timestamp'];
    final timestamp = _parseTimestamp(timestampRaw) ?? DateTime.now();

    return Bookmark(
      uuid: uuid,
      latitude: lat,
      longitude: log,
      timestamp: timestamp,
      imagePath: resolvedImagePath,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }

  static String? _resolveImagePath(dynamic rawPath) {
    if (rawPath == null) return null;
    final text = rawPath.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      if (text.contains('/prod/image')) return text;
      if (text.contains('.s3.') || text.contains('amazonaws.com/')) {
        final key = _extractS3Key(text);
        if (key != null) {
          return '$_imageEndpoint?key=${Uri.encodeQueryComponent(key)}';
        }
      }
      return text;
    }
    return '$_imageEndpoint?key=${Uri.encodeQueryComponent(text)}';
  }

  static String? _extractS3Key(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.isEmpty) return null;
      return path.startsWith('/') ? path.substring(1) : path;
    } catch (_) {
      return null;
    }
  }
}
