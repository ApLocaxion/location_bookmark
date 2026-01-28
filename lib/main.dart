import 'package:flutter/material.dart';

import 'bookmarks_page.dart';
import 'login_page.dart';
import 'upload_page.dart';

void main() {
  debugPrint('App: main');
  runApp(const LocationBookmarkApp());
}

class LocationBookmarkApp extends StatelessWidget {
  const LocationBookmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('App: build');
    return MaterialApp(
      title: 'Locaxtion Bookmark',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const LoginPage(),
        '/upload': (_) => const UploadPage(),
        '/capture': (_) => const UploadPage(mode: UploadMode.capture),
        '/list': (_) => const BookmarkListPage(),
        '/map': (_) => const BookmarkMapPage(),
      },
      initialRoute: '/',
    );
  }
}
