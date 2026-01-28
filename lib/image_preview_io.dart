import 'dart:io';

import 'package:flutter/material.dart';

Widget buildBookmarkImage(String imagePath) {
  return Image.file(File(imagePath));
}
