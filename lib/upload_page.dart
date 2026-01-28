import 'dart:convert';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heckofaheic/heckofaheic.dart';
import 'package:image_picker/image_picker.dart';

import 'bookmark_data.dart';
import 'exif_debug_page.dart';
import 'image_store.dart';

enum UploadMode { capture, upload }

class UploadPage extends StatefulWidget {
  const UploadPage({super.key, this.mode = UploadMode.upload});

  final UploadMode mode;

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imagePath;
  double? _latitude;
  double? _longitude;
  DateTime? _timestamp;
  bool _loading = false;
  String? _statusMessage;
  List<String>? _tagLines;
  String? _xmpRaw;
  String? _cameraSource;

  Future<void> _pickImageFromGallery() async {
    debugPrint('UploadPage: pick image (gallery) start');
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        debugPrint('UploadPage: pick image canceled');
        setState(() {
          _loading = false;
          _statusMessage = 'No image selected.';
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      final displayBytes = await _prepareBytesForDisplay(bytes);
      final tags = await readExifFromBytes(bytes);

      final tagLines = _dumpExifTags(tags);
      _logGpsXmpTags(tags);
      final cameraSource = _detectCameraSource(tags);
      debugPrint('UploadPage: camera source=$cameraSource');
      final xmpRaw = _extractXmpMetadata(bytes);
      if (xmpRaw != null) {
        debugPrint('UploadPage: XMP length=${xmpRaw.length}');
      } else {
        debugPrint('UploadPage: XMP not found');
      }
      _logAllExif(tags, tagLines, xmpRaw);

      final gpsResult = _extractGps(tags, xmpRaw);
      final timestamp = _extractTimestamp(tags);

      debugPrint(
        'UploadPage: gps=${gpsResult.data == null ? 'null' : '${gpsResult.data!.latitude},${gpsResult.data!.longitude}'} '
        'timestamp=$timestamp',
      );

      _applyPickedImage(
        picked: picked,
        bytes: displayBytes,
        latitude: gpsResult.data?.latitude,
        longitude: gpsResult.data?.longitude,
        timestamp: timestamp,
        tagLines: tagLines,
        xmpRaw: xmpRaw,
        cameraSource: cameraSource,
        statusMessage: gpsResult.data == null
            ? (gpsResult.warning ?? 'No GPS metadata found in this image.')
            : 'Metadata extracted successfully.',
      );
    } catch (error) {
      debugPrint('UploadPage: gallery metadata read failed: $error');
      setState(() {
        _loading = false;
        _statusMessage = 'Failed to read metadata: $error';
      });
    }
  }

  Future<void> _captureImageWithLocation() async {
    debugPrint('UploadPage: capture image start');
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked == null) {
        debugPrint('UploadPage: capture canceled');
        setState(() {
          _loading = false;
          _statusMessage = 'No image captured.';
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      final displayBytes = await _prepareBytesForDisplay(bytes);
      final position = await _tryGetCurrentPosition();
      final timestamp = DateTime.now();
      final statusMessage = position == null
          ? 'Captured photo. Location permission denied or unavailable.'
          : 'Captured photo with current location.';

      _applyPickedImage(
        picked: picked,
        bytes: displayBytes,
        latitude: position?.latitude,
        longitude: position?.longitude,
        timestamp: timestamp,
        tagLines: null,
        xmpRaw: null,
        cameraSource: 'Captured (device)',
        statusMessage: statusMessage,
      );
    } catch (error) {
      debugPrint('UploadPage: capture failed: $error');
      setState(() {
        _loading = false;
        _statusMessage = 'Failed to capture image: $error';
      });
    }
  }

  Future<Uint8List> _prepareBytesForDisplay(Uint8List bytes) async {
    if (!kIsWeb) {
      return bytes;
    }

    try {
      if (HeckOfAHeic.isHEIC(bytes)) {
        final converted = await HeckOfAHeic.convert(
          bytes,
          toType: TargetType.jpeg,
          jpegQuality: 0.9,
        );
        if (converted.isNotEmpty) {
          debugPrint(
            'UploadPage: converted HEIC to JPEG bytes=${converted.length}',
          );
          return converted;
        }
      }
    } catch (error) {
      debugPrint('UploadPage: HEIC conversion failed: $error');
    }

    return bytes;
  }

  Future<Position?> _tryGetCurrentPosition() async {
    debugPrint('UploadPage: get current position');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _applyPickedImage({
    required XFile picked,
    required Uint8List bytes,
    required double? latitude,
    required double? longitude,
    required DateTime? timestamp,
    required List<String>? tagLines,
    required String? xmpRaw,
    required String? cameraSource,
    required String statusMessage,
  }) {
    debugPrint(
      'UploadPage: apply picked image bytes=${bytes.length} lat=$latitude lon=$longitude ts=$timestamp',
    );
    setState(() {
      _imageBytes = bytes;
      _imagePath = kIsWeb ? null : picked.path;
      _latitude = latitude;
      _longitude = longitude;
      _timestamp = timestamp;
      _tagLines = tagLines;
      _xmpRaw = xmpRaw;
      _cameraSource = cameraSource;
      _loading = false;
      _statusMessage = statusMessage;
    });
  }

  Future<void> _saveBookmark() async {
    debugPrint(
      'UploadPage: save bookmark lat=$_latitude lon=$_longitude ts=$_timestamp',
    );
    if (_timestamp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing timestamp metadata.')),
      );
      return;
    }

    var imagePath = _imagePath;
    if (kIsWeb && imagePath == null && _imageBytes != null) {
      try {
        imagePath = await saveImageBytes(_imageBytes!);
      } catch (error) {
        debugPrint('UploadPage: save image failed: $error');
      }
    }

    final bookmark = Bookmark(
      latitude: _latitude,
      longitude: _longitude,
      timestamp: _timestamp!,
      imagePath: imagePath,
    );

    await BookmarkDatabase.instance.insertBookmark(bookmark);

    if (!mounted) return;
    final baseMessage = (_latitude == null || _longitude == null)
        ? 'Bookmark saved without location data.'
        : 'Bookmark saved.';
    final message = (kIsWeb && imagePath == null)
        ? '$baseMessage (Image not saved.)'
        : baseMessage;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pushReplacementNamed('/list');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('UploadPage: build loading=$_loading');
    final isCapture = widget.mode == UploadMode.capture;
    return Scaffold(
      appBar: AppBar(
        title: Text(isCapture ? 'Capture Photo' : 'Upload Photo'),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.home_outlined),
          ),
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
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover),
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
            onPressed: _loading
                ? null
                : (isCapture
                      ? _captureImageWithLocation
                      : _pickImageFromGallery),
            icon: Icon(
              isCapture
                  ? Icons.photo_camera_outlined
                  : Icons.photo_library_outlined,
            ),
            label: Text(
              _loading
                  ? (isCapture ? 'Capturing photo...' : 'Reading metadata...')
                  : (isCapture ? 'Capture Photo' : 'Pick Image'),
            ),
          ),
          if (!isCapture && kIsWeb) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: On mobile Chrome, choose Files > DCIM/Camera to keep GPS. '
              'Google Photos often strips location metadata.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          _MetadataCard(
            latitude: _latitude,
            longitude: _longitude,
            timestamp: _timestamp,
            statusMessage: _statusMessage,
            cameraSource: _cameraSource,
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
    required this.cameraSource,
  });

  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;
  final String? statusMessage;
  final String? cameraSource;

  @override
  Widget build(BuildContext context) {
    debugPrint('UploadPage: metadata card build');
    final latText = latitude == null ? 'Unknown' : latitude!.toStringAsFixed(6);
    final lonText = longitude == null
        ? 'Unknown'
        : longitude!.toStringAsFixed(6);
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
            Text('Latitude: $latText'),
            Text('Longitude: $lonText'),
            Text('Timestamp: ${timestamp?.toLocal().toString() ?? '--'}'),
            Text('Camera source: ${cameraSource ?? 'Unknown'}'),
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

class _GpsParseResult {
  const _GpsParseResult(this.data, this.warning);

  final _GpsData? data;
  final String? warning;
}

_GpsParseResult _extractGps(Map<String, IfdTag> tags, String? xmpRaw) {
  debugPrint('UploadPage: extract GPS tags=${tags.length}');
  final latTag = _firstTag(tags, ['GPS GPSLatitude', 'GPSLatitude']);
  final lonTag = _firstTag(tags, ['GPS GPSLongitude', 'GPSLongitude']);
  if (latTag == null || lonTag == null) {
    final xmpFallback = _extractGpsFromXmp(xmpRaw);
    if (xmpFallback != null) {
      return _GpsParseResult(xmpFallback, null);
    }
    return const _GpsParseResult(null, 'No GPS metadata found in this image.');
  }

  final latValues = latTag.values;
  final lonValues = lonTag.values;

  debugPrint(
    'UploadPage: raw GPS lat=${latTag.printable} lon=${lonTag.printable}',
  );
  if (latValues.length < 3 || lonValues.length < 3) {
    return const _GpsParseResult(null, 'GPS metadata is incomplete.');
  }
  final latList = latValues.toList();
  final lonList = lonValues.toList();
  if (_containsZeroRatios(latList) || _containsZeroRatios(lonList)) {
    final xmpFallback = _extractGpsFromXmp(xmpRaw);
    if (xmpFallback != null) {
      return _GpsParseResult(xmpFallback, 'GPS parsed from XMP metadata.');
    }
    final warning = kIsWeb
        ? 'GPS metadata is invalid (0/0 ratios). On mobile web, '
              'pick the original file from Files > DCIM (Google Photos may strip GPS).'
        : 'GPS metadata is invalid (0/0 ratios).';
    return _GpsParseResult(null, warning);
  }

  final latitude = _convertToDegrees(latList);
  final longitude = _convertToDegrees(lonList);
  if (latitude == null || longitude == null) {
    final xmpFallback = _extractGpsFromXmp(xmpRaw);
    if (xmpFallback != null) {
      return _GpsParseResult(xmpFallback, 'GPS parsed from XMP metadata.');
    }
    return const _GpsParseResult(null, 'Unable to parse GPS metadata.');
  }

  final latRef = _firstTag(tags, [
    'GPS GPSLatitudeRef',
    'GPSLatitudeRef',
  ])?.printable.toUpperCase();
  final lonRef = _firstTag(tags, [
    'GPS GPSLongitudeRef',
    'GPSLongitudeRef',
  ])?.printable.toUpperCase();

  final finalLat = (latRef == 'S') ? -latitude : latitude;
  final finalLon = (lonRef == 'W') ? -longitude : longitude;

  return _GpsParseResult(_GpsData(finalLat, finalLon), null);
}

DateTime? _extractTimestamp(Map<String, IfdTag> tags) {
  debugPrint('UploadPage: extract timestamp');
  final tag = _firstTag(tags, [
    'EXIF DateTimeOriginal',
    'EXIF DateTimeDigitized',
    'Image DateTime',
  ]);
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
  debugPrint('UploadPage: convert to degrees values=$values');
  if (values.length < 3) return null;
  final deg = _ratioToDouble(values[0]);
  final min = _ratioToDouble(values[1]);
  final sec = _ratioToDouble(values[2]);
  if (deg == null || min == null || sec == null) return null;
  return deg + (min / 60.0) + (sec / 3600.0);
}

double? _ratioToDouble(dynamic value) {
  debugPrint('UploadPage: ratio to double value=$value');
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

void _logGpsXmpTags(Map<String, IfdTag> tags) {
  debugPrint('UploadPage: log GPS/XMP tags');
  final keys = tags.keys.toList()..sort();
  for (final key in keys) {
    final upper = key.toUpperCase();
    if (upper.contains('GPS') || upper.contains('XMP')) {
      debugPrint('UploadPage: tag $key=${tags[key]?.printable}');
    }
  }
}

void _logAllExif(
  Map<String, IfdTag> tags,
  List<String> tagLines,
  String? xmpRaw,
) {
  debugPrint('UploadPage: EXIF tag count=${tags.length}');
  for (final line in tagLines) {
    debugPrint('UploadPage: exif $line');
  }
  if (xmpRaw == null || xmpRaw.isEmpty) {
    debugPrint('UploadPage: XMP raw empty');
    return;
  }
  debugPrint('UploadPage: XMP raw start');
  _logLongString('UploadPage: xmp', xmpRaw);
  debugPrint('UploadPage: XMP raw end');
}

void _logLongString(String prefix, String text, {int chunkSize = 800}) {
  if (text.isEmpty) return;
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
    debugPrint('$prefix ${text.substring(i, end)}');
  }
}

List<String> _dumpExifTags(Map<String, IfdTag> tags) {
  debugPrint('UploadPage: dump EXIF tags');
  final entries = tags.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return entries
      .map((entry) => '${entry.key}: ${entry.value.printable}')
      .toList(growable: false);
}

String? _extractXmpMetadata(Uint8List bytes) {
  debugPrint('UploadPage: extract XMP metadata');
  final data = utf8.decode(bytes, allowMalformed: true);
  final match = RegExp(
    r'<x:xmpmeta[^>]*>.*?</x:xmpmeta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(data);
  return match?.group(0);
}

_GpsData? _extractGpsFromXmp(String? xmpRaw) {
  debugPrint('UploadPage: extract GPS from XMP');
  if (xmpRaw == null || xmpRaw.isEmpty) return null;
  final latValue = _readXmpValue(xmpRaw, 'exif:GPSLatitude');
  final lonValue = _readXmpValue(xmpRaw, 'exif:GPSLongitude');
  if (latValue == null || lonValue == null) return null;
  debugPrint('UploadPage: XMP GPS lat=$latValue lon=$lonValue');
  final lat = _parseXmpCoordinate(latValue, isLatitude: true);
  final lon = _parseXmpCoordinate(lonValue, isLatitude: false);
  if (lat == null || lon == null) return null;
  return _GpsData(lat, lon);
}

String? _readXmpValue(String xmpRaw, String key) {
  final attrPattern = RegExp('$key\\s*=\\s*\"([^\"]+)\"', caseSensitive: false);
  final attrMatch = attrPattern.firstMatch(xmpRaw);
  if (attrMatch != null) return attrMatch.group(1);

  final nodePattern = RegExp('<$key>([^<]+)</$key>', caseSensitive: false);
  final nodeMatch = nodePattern.firstMatch(xmpRaw);
  return nodeMatch?.group(1);
}

double? _parseXmpCoordinate(String value, {required bool isLatitude}) {
  debugPrint('UploadPage: parse XMP coord value=$value');
  var text = value.trim();
  if (text.isEmpty) return null;

  var direction = '';
  final lastChar = text.substring(text.length - 1).toUpperCase();
  if ('NSEW'.contains(lastChar)) {
    direction = lastChar;
    text = text.substring(0, text.length - 1).trim();
  }

  text = text.replaceAll(RegExp("[\u00B0'\"]"), ' ');
  text = text.replaceAll(',', ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  final parts = text.split(' ');
  final numbers = parts
      .map((part) => double.tryParse(part))
      .whereType<double>()
      .toList();
  if (numbers.isEmpty) return null;

  double valueDecimal;
  if (numbers.length == 1) {
    valueDecimal = numbers[0];
  } else if (numbers.length == 2) {
    valueDecimal = numbers[0] + (numbers[1] / 60.0);
  } else {
    valueDecimal = numbers[0] + (numbers[1] / 60.0) + (numbers[2] / 3600.0);
  }

  if (direction == 'S' || direction == 'W') {
    valueDecimal = -valueDecimal.abs();
  }

  if (isLatitude && valueDecimal.abs() > 90) return null;
  if (!isLatitude && valueDecimal.abs() > 180) return null;
  return valueDecimal;
}

IfdTag? _firstTag(Map<String, IfdTag> tags, List<String> keys) {
  debugPrint('UploadPage: first tag lookup keys=$keys');
  for (final key in keys) {
    final tag = tags[key];
    if (tag != null) {
      return tag;
    }
  }
  return null;
}

bool _containsZeroRatios(List values) {
  debugPrint('UploadPage: check zero ratios values=$values');
  for (final value in values) {
    if (value is Ratio && value.denominator == 0) {
      return true;
    }
  }
  return false;
}

String? _detectCameraSource(Map<String, IfdTag> tags) {
  final make = _firstTag(tags, ['Image Make', 'Make'])?.printable ?? '';
  final model = _firstTag(tags, ['Image Model', 'Model'])?.printable ?? '';
  final combined = '$make $model'.trim().toLowerCase();
  if (combined.isEmpty) {
    return null;
  }
  if (combined.contains('apple') || combined.contains('iphone')) {
    return 'iPhone (iOS)';
  }
  if (combined.contains('samsung') ||
      combined.contains('pixel') ||
      combined.contains('oneplus') ||
      combined.contains('xiaomi') ||
      combined.contains('motorola') ||
      combined.contains('huawei') ||
      combined.contains('oppo') ||
      combined.contains('vivo') ||
      combined.contains('sony') ||
      combined.contains('lg') ||
      combined.contains('nokia') ||
      combined.contains('android')) {
    return 'Android';
  }
  return 'Other ($make ${model.trim()})'.trim();
}
