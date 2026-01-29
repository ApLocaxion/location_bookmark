import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Bookmark {
  Bookmark({
    this.uuid,
    this.id,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.imagePath,
  });

  final String? uuid;
  final int? id;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final String? imagePath;

  Map<String, Object?> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'image_path': imagePath,
    };
  }

  static Bookmark fromMap(Map<String, Object?> map) {
    return Bookmark(
      uuid: map['uuid'] as String?,
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
  static const _dbName = 'location_bookmarks.db';
  static const _dbVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS bookmarks');
        await _createSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL,
        longitude REAL,
        timestamp TEXT NOT NULL,
        image_path TEXT
      )
    ''');
  }

  Future<int> insertBookmark(Bookmark bookmark) async {
    debugPrint(
      'BookmarkDatabase: insert lat=${bookmark.latitude} lon=${bookmark.longitude} ts=${bookmark.timestamp}',
    );
    final db = await database;
    return db.insert('bookmarks', bookmark.toMap());
  }

  Future<List<Bookmark>> fetchBookmarks() async {
    debugPrint('BookmarkDatabase: fetch bookmarks');
    final db = await database;
    final rows = await db.query('bookmarks', orderBy: 'timestamp DESC');
    return rows.map(Bookmark.fromMap).toList();
  }
}
