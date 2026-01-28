import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'image_store.dart';

Widget buildBookmarkImage(String imagePath) {
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
