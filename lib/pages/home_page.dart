import 'package:flutter/material.dart';

import '../services/auth_storage.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('HomePage: build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('LocaXion Bookmark'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthStorage.clearAccessToken();
              await AuthStorage.clearIdToken();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.location_pin, size: 64),
                const SizedBox(height: 16),
                Text(
                  'LocaXion Bookmark',
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
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/list');
                  },
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('View List'),
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
