import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'bookmark_data.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  double? _latitude;
  double? _longitude;
  DateTime? _timestamp;
  bool _loading = false;
  String? _statusMessage;

  Future<void> _pickImage() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        setState(() {
          _loading = false;
          _statusMessage = 'No image selected.';
        });
        return;
      }

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);

      final gps = _extractGps(tags);
      final timestamp = _extractTimestamp(tags);

      setState(() {
        _imageFile = file;
        _latitude = gps?.latitude;
        _longitude = gps?.longitude;
        _timestamp = timestamp;
        _loading = false;
        if (gps == null) {
          _statusMessage = 'No GPS metadata found in this image.';
        } else {
          _statusMessage = 'Metadata extracted successfully.';
        }
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _statusMessage = 'Failed to read metadata: $error';
      });
    }
  }

  Future<void> _saveBookmark() async {
    if (_latitude == null || _longitude == null || _timestamp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing GPS or timestamp metadata.')),
      );
      return;
    }

    final bookmark = Bookmark(
      latitude: _latitude!,
      longitude: _longitude!,
      timestamp: _timestamp!,
      imagePath: _imageFile?.path,
    );

    await BookmarkDatabase.instance.insertBookmark(bookmark);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark saved.')),
    );
    Navigator.of(context).pushReplacementNamed('/list');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Photo'),
        actions: [
          IconButton(
            tooltip: 'View bookmarks',
            onPressed: () => Navigator.of(context).pushNamed('/list'),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_imageFile!, height: 220, fit: BoxFit.cover),
            )
          else
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('No image selected')),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_loading ? 'Reading metadata...' : 'Pick Image'),
          ),
          const SizedBox(height: 16),
          _MetadataCard(
            latitude: _latitude,
            longitude: _longitude,
            timestamp: _timestamp,
            statusMessage: _statusMessage,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _saveBookmark,
            child: const Text('Save Bookmark'),
          ),
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.statusMessage,
  });

  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extracted Metadata',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Latitude: ${latitude?.toStringAsFixed(6) ?? '--'}'),
            Text('Longitude: ${longitude?.toStringAsFixed(6) ?? '--'}'),
            Text('Timestamp: ${timestamp?.toLocal().toString() ?? '--'}'),
            if (statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                statusMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GpsData {
  const _GpsData(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

_GpsData? _extractGps(Map<String, IfdTag> tags) {
  final latTag = tags['GPS GPSLatitude'];
  final lonTag = tags['GPS GPSLongitude'];
  if (latTag == null || lonTag == null) return null;

  final latValues = latTag.values;
  final lonValues = lonTag.values;

  if (latValues.length < 3 || lonValues.length < 3) return null;
  final latList = latValues.toList();
  final lonList = lonValues.toList();

  final latitude = _convertToDegrees(latList);
  final longitude = _convertToDegrees(lonList);
  if (latitude == null || longitude == null) return null;

  final latRef = tags['GPS GPSLatitudeRef']?.printable.toUpperCase();
  final lonRef = tags['GPS GPSLongitudeRef']?.printable.toUpperCase();

  final finalLat = (latRef == 'S') ? -latitude : latitude;
  final finalLon = (lonRef == 'W') ? -longitude : longitude;

  return _GpsData(finalLat, finalLon);
}

DateTime? _extractTimestamp(Map<String, IfdTag> tags) {
  final tag = tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'];
  final printable = tag?.printable;
  if (printable == null) return null;

  final parts = printable.split(' ');
  if (parts.length != 2) return null;
  final dateParts = parts[0].split(':');
  final timeParts = parts[1].split(':');
  if (dateParts.length != 3 || timeParts.length != 3) return null;

  final year = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final day = int.tryParse(dateParts[2]);
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  final second = int.tryParse(timeParts[2]);

  if ([year, month, day, hour, minute, second].contains(null)) return null;

  return DateTime(year!, month!, day!, hour!, minute!, second!);
}

double? _convertToDegrees(List values) {
  if (values.length < 3) return null;
  final deg = _ratioToDouble(values[0]);
  final min = _ratioToDouble(values[1]);
  final sec = _ratioToDouble(values[2]);
  if (deg == null || min == null || sec == null) return null;
  return deg + (min / 60.0) + (sec / 3600.0);
}

double? _ratioToDouble(dynamic value) {
  if (value is Ratio) {
    if (value.denominator == 0) {
      return null;
    }
    return value.numerator / value.denominator;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is double) {
    return value;
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
