import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

Widget buildBookmarkImage(String imagePath) {
  final data = imagePath.startsWith('data:')
      ? imagePath.split(',').last
      : imagePath;
  Uint8List? bytes;
  try {
    bytes = base64Decode(data);
  } catch (_) {
    bytes = null;
  }
  if (bytes == null || bytes.isEmpty) {
    return const Text('Image unavailable on web.');
  }
  return Image.memory(bytes);
}
