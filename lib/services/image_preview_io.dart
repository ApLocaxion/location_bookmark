import 'dart:io';

import 'package:flutter/material.dart';

Widget buildBookmarkImage(String imagePath) {
  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    return Image.network(imagePath);
  }
  return Image.file(File(imagePath));
}
