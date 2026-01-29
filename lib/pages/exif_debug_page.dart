import 'package:flutter/material.dart';

class ExifDebugPage extends StatelessWidget {
  const ExifDebugPage({
    super.key,
    required this.tagLines,
    required this.xmpRaw,
  });

  final List<String> tagLines;
  final String? xmpRaw;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EXIF Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'XMP Metadata',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(xmpRaw ?? 'No XMP metadata found.'),
          const SizedBox(height: 24),
          Text(
            'EXIF Tags',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (tagLines.isEmpty)
            const Text('No EXIF tags found.')
          else
            ...tagLines.map(SelectableText.new),
        ],
      ),
    );
  }
}
