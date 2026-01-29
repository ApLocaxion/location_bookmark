import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'image_store.dart';

Widget buildBookmarkImage(String imagePath) {
  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    if (!imagePath.contains('/prod/image')) {
      return Image.network(imagePath);
    }
    return FutureBuilder<Uint8List>(
      future: _loadProxyImage(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('Image unavailable on web.');
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Text('Image unavailable on web.');
        }
        return Image.memory(bytes);
      },
    );
  }
  if (imagePath.startsWith('idb:')) {
    return FutureBuilder<Uint8List?>(
      future: loadImageBytes(imagePath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Text('Image unavailable on web.');
        }
        return Image.memory(bytes);
      },
    );
  }

  try {
    final data = imagePath.startsWith('data:')
        ? imagePath.split(',').last
        : imagePath;
    final bytes = base64Decode(data);
    return Image.memory(bytes);
  } catch (_) {
    return const Text('Image unavailable on web.');
  }
}

Future<Uint8List> _loadProxyImage(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Image fetch failed: ${response.statusCode}');
  }
  final bytes = response.bodyBytes;
  if (_looksLikeJpeg(bytes) || _looksLikePng(bytes)) {
    return bytes;
  }
  if (_looksLikeBase64Jpeg(bytes) || _looksLikeBase64Png(bytes)) {
    final decoded = base64Decode(utf8.decode(bytes));
    return decoded;
  }
  return bytes;
}

bool _looksLikeJpeg(Uint8List bytes) {
  return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}

bool _looksLikePng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

bool _looksLikeBase64Jpeg(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x2F && // /
      bytes[1] == 0x39 && // 9
      bytes[2] == 0x6A && // j
      bytes[3] == 0x2F;   // /
}

bool _looksLikeBase64Png(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x69 && // i
      bytes[1] == 0x56 && // V
      bytes[2] == 0x42 && // B
      bytes[3] == 0x4F;   // O
}
