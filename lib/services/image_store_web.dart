import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

const _dbName = 'location_bookmark_db';
const _storeName = 'images';

Future<String?> saveImageBytes(Uint8List bytes) async {
  final db = await _openDb();
  final key = 'img_${DateTime.now().millisecondsSinceEpoch}';
  final base64Data = base64Encode(bytes);
  final tx = db.transaction(_storeName, 'readwrite');
  final store = tx.objectStore(_storeName);
  await store.put({'id': key, 'data': base64Data});
  await tx.completed;
  return 'idb:$key';
}

Future<Uint8List?> loadImageBytes(String imageKey) async {
  if (!imageKey.startsWith('idb:')) return null;
  final key = imageKey.substring(4);
  final db = await _openDb();
  final tx = db.transaction(_storeName, 'readonly');
  final store = tx.objectStore(_storeName);
  final record = await store.getObject(key);
  await tx.completed;
  if (record is Map && record['data'] is String) {
    return base64Decode(record['data'] as String);
  }
  return null;
}

Future<dynamic> _openDb() async {
  try {
    final db = await html.window.indexedDB!.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (event) {
        final db = (event.target as dynamic).result;
        if (!db.objectStoreNames!.contains(_storeName)) {
          db.createObjectStore(_storeName, keyPath: 'id');
        }
      },
    );
    return db;
  } catch (error) {
    throw (error ?? 'IndexedDB open failed');
  }
}
