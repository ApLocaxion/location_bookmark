import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import 'bookmark_data.dart';
import 'image_preview.dart';

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
    debugPrint('BookmarkListPage: initState');
    _reload();
  }

  void _reload() {
    debugPrint('BookmarkListPage: reload');
    _bookmarksFuture = BookmarkDatabase.instance.fetchBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BookmarkListPage: build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.home_outlined),
          ),
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
              final hasLocation =
                  item.latitude != null && item.longitude != null;
              final locationText = hasLocation
                  ? '${item.latitude!.toStringAsFixed(5)}, '
                        '${item.longitude!.toStringAsFixed(5)}'
                  : 'Unknown location';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(locationText),
                  subtitle: Text(item.timestamp.toLocal().toString()),
                  trailing: item.imagePath == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.image_outlined),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: buildBookmarkImage(item.imagePath!),
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

  void _showNearbyPhotos(
    BuildContext context,
    List<Bookmark> bookmarks,
    LatLng center,
  ) {
    const nearbyRadiusMeters = 5000.0;
    final distance = const Distance();
    final photos =
        bookmarks
            .where(
              (bookmark) =>
                  bookmark.imagePath != null &&
                  bookmark.latitude != null &&
                  bookmark.longitude != null,
            )
            .map((bookmark) {
              final point = LatLng(bookmark.latitude!, bookmark.longitude!);
              final meters = distance.as(LengthUnit.Meter, center, point);
              return _NearbyPhoto(bookmark: bookmark, meters: meters);
            })
            .toList()
          ..sort((a, b) => a.meters.compareTo(b.meters));

    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo bookmarks with location data.')),
      );
      return;
    }

    final nearbyPhotos = photos
        .where((photo) => photo.meters <= nearbyRadiusMeters)
        .toList();
    final displayPhotos = nearbyPhotos.isNotEmpty ? nearbyPhotos : photos;
    final titleSuffix = nearbyPhotos.isNotEmpty ? 'within 5 km' : 'all photos';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final sheetHeight = MediaQuery.of(context).size.height * 0.6;
        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby photos ($titleSuffix)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: displayPhotos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = displayPhotos[index];
                        final bookmark = entry.bookmark;
                        final distanceKm = entry.meters / 1000.0;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: buildBookmarkImage(bookmark.imagePath!),
                            ),
                          ),
                          title: Text(
                            '${bookmark.latitude!.toStringAsFixed(5)}, '
                            '${bookmark.longitude!.toStringAsFixed(5)}',
                          ),
                          subtitle: Text(
                            '${distanceKm.toStringAsFixed(2)} km away',
                          ),
                          onTap: () => _showBookmarkDetails(context, bookmark),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoMarker(BuildContext context, Bookmark bookmark) {
    if (bookmark.imagePath == null) {
      return const Icon(Icons.location_on, color: Colors.red, size: 36);
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 52,
          height: 52,
          child: buildBookmarkImage(bookmark.imagePath!),
        ),
      ),
    );
  }

  Widget _pillButton({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: child,
        ),
      ),
    );
  }

  void _showBookmarkDetails(BuildContext context, Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final hasLocation =
            bookmark.latitude != null && bookmark.longitude != null;
        final locationText = hasLocation
            ? '${bookmark.latitude!.toStringAsFixed(5)}, '
                  '${bookmark.longitude!.toStringAsFixed(5)}'
            : 'Unknown location';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bookmark Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(locationText),
              Text(bookmark.timestamp.toLocal().toString()),
              if (bookmark.imagePath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: buildBookmarkImage(bookmark.imagePath!),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BookmarkMapPage: build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Map'),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
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

          final locations = bookmarks
              .where(
                (bookmark) =>
                    bookmark.latitude != null && bookmark.longitude != null,
              )
              .toList();
          if (locations.isEmpty) {
            return const Center(
              child: Text('No bookmarks with location data to display.'),
            );
          }

          final markers = locations
              .map(
                (bookmark) => Marker(
                  width: 64,
                  height: 64,
                  point: LatLng(bookmark.latitude!, bookmark.longitude!),
                  child: GestureDetector(
                    onTap: () => _showBookmarkDetails(context, bookmark),
                    child: _buildPhotoMarker(context, bookmark),
                  ),
                ),
              )
              .toList();

          final center = LatLng(
            locations.first.latitude!,
            locations.first.longitude!,
          );

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 12),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.location_bookmark',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                left: 16,
                top: 16,
                child: _pillButton(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.close),
                ),
              ),

              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Center(
                  child: _pillButton(
                    onTap: () => _showNearbyPhotos(context, bookmarks, center),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.photo_library_outlined),
                        SizedBox(width: 8),
                        Text('Show Nearby Photos'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NearbyPhoto {
  const _NearbyPhoto({required this.bookmark, required this.meters});

  final Bookmark bookmark;
  final double meters;
}
