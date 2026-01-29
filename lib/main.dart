import 'package:flutter/material.dart';

import 'pages/bookmarks_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/upload_page.dart';

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
      debugShowCheckedModeBanner: false,
      title: 'LocaXion Bookmark',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const LoginPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/signup': (_) => const SignupPage(),
        '/upload': (_) => const UploadPage(),
        '/capture': (_) => const UploadPage(mode: UploadMode.capture),
        '/list': (_) => const BookmarkListPage(),
        '/map': (_) => const BookmarkMapPage(),
      },
      initialRoute: '/',
    );
  }
}
