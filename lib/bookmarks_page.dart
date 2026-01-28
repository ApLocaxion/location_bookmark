import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'bookmark_data.dart';

class BookmarkListPage extends StatefulWidget {
  const BookmarkListPage({super.key});

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  Future<List<Bookmark>>? _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _bookmarksFuture = BookmarkDatabase.instance.fetchBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        actions: [
          IconButton(
            tooltip: 'View map',
            onPressed: () => Navigator.of(context).pushNamed('/map'),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushReplacementNamed('/upload'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<List<Bookmark>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bookmarks = snapshot.data ?? [];
          if (bookmarks.isEmpty) {
            return const Center(child: Text('No bookmarks saved yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookmarks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = bookmarks[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    '${item.latitude.toStringAsFixed(5)}, '
                    '${item.longitude.toStringAsFixed(5)}',
                  ),
                  subtitle: Text(item.timestamp.toLocal().toString()),
                  trailing: item.imagePath == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.image_outlined),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: Image.file(File(item.imagePath!)),
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BookmarkMapPage extends StatelessWidget {
  const BookmarkMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Map')),
      body: FutureBuilder<List<Bookmark>>(
        future: BookmarkDatabase.instance.fetchBookmarks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bookmarks = snapshot.data ?? [];
          if (bookmarks.isEmpty) {
            return const Center(child: Text('No bookmarks to display.'));
          }

          final markers = bookmarks
              .map(
                (bookmark) => Marker(
                  width: 40,
                  height: 40,
                  point: LatLng(bookmark.latitude, bookmark.longitude),
                  child: const Icon(Icons.location_on, color: Colors.red),
                ),
              )
              .toList();

          final center = LatLng(
            bookmarks.first.latitude,
            bookmarks.first.longitude,
          );

          return FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.location_bookmark',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
