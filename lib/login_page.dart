import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('LoginPage: build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Locaxtion Bookmark'),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.location_pin, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Locaxtion Bookmark',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/capture');
                  },
                  child: const Text('Capture Photo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/upload');
                  },
                  child: const Text('Upload Photo'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/map');
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View Map'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose capture to save current GPS.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
