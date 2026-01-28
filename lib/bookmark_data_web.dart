import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

class Bookmark {
  Bookmark({
    this.id,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.imagePath,
  });

  final int? id;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final String? imagePath;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'image_path': imagePath,
    };
  }

  static Bookmark fromMap(Map<String, Object?> map) {
    return Bookmark(
      id: map['id'] as int?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      imagePath: map['image_path'] as String?,
    );
  }
}

class BookmarkDatabase {
  BookmarkDatabase._();

  static final BookmarkDatabase instance = BookmarkDatabase._();
  static const _storageKey = 'location_bookmarks';

  Future<int> insertBookmark(Bookmark bookmark) async {
    debugPrint(
      'BookmarkDatabase(web): insert lat=${bookmark.latitude} lon=${bookmark.longitude} ts=${bookmark.timestamp}',
    );
    final items = _loadItems();
    final nextId = _nextId(items);
    items.add(
      Bookmark(
        id: nextId,
        latitude: bookmark.latitude,
        longitude: bookmark.longitude,
        timestamp: bookmark.timestamp,
        imagePath: bookmark.imagePath,
      ),
    );
    try {
      _saveItems(items);
    } catch (error) {
      debugPrint('BookmarkDatabase(web): save failed: $error');
      if (bookmark.imagePath != null) {
        debugPrint('BookmarkDatabase(web): retry without imagePath');
        items.removeLast();
        items.add(
          Bookmark(
            id: nextId,
            latitude: bookmark.latitude,
            longitude: bookmark.longitude,
            timestamp: bookmark.timestamp,
            imagePath: null,
          ),
        );
        _saveItems(items);
      } else {
        rethrow;
      }
    }
    return nextId;
  }

  Future<List<Bookmark>> fetchBookmarks() async {
    debugPrint('BookmarkDatabase(web): fetch bookmarks');
    final items = _loadItems();
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  List<Bookmark> _loadItems() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Bookmark.fromMap(item.cast<String, Object?>()))
          .toList();
    } catch (error) {
      debugPrint('BookmarkDatabase(web): load failed: $error');
      return [];
    }
  }

  void _saveItems(List<Bookmark> items) {
    final encoded = jsonEncode(items.map((item) => item.toMap()).toList());
    html.window.localStorage[_storageKey] = encoded;
  }

  int _nextId(List<Bookmark> items) {
    if (items.isEmpty) return 1;
    final maxId = items
        .map((item) => item.id ?? 0)
        .fold<int>(0, (prev, next) => next > prev ? next : prev);
    return maxId + 1;
  }
}
