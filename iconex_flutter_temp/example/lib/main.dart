import 'package:flutter/material.dart';
import 'package:iconex_flutter/iconex_flutter.dart';

void main() {
  runApp(const IconexExampleApp());
}

/// A minimal example showcasing the Iconex Flutter icons.
class IconexExampleApp extends StatelessWidget {
  const IconexExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iconex Example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const IconexHomePage(),
    );
  }
}

/// Displays example icons from all available styles.
class IconexHomePage extends StatelessWidget {
  const IconexHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iconex Example'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24.0,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [
                Text('Light',
                  style: theme.textTheme.titleMedium,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 16.0,
                  children: [
                    Icon(Iconex.light.home,
                      size: 32.0,
                    ),
                    Icon(Iconex.light.search,
                      size: 32.0,
                    ),
                    Icon(Iconex.light.heart,
                      size: 32.0,
                    ),
                  ],
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [
                Text('Filled',
                  style: theme.textTheme.titleMedium,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 16.0,
                  children: [
                    Icon(Iconex.filled.home,
                      size: 32.0,
                    ),
                    Icon(Iconex.filled.search,
                      size: 32.0,
                    ),
                    Icon(Iconex.filled.heart,
                      size: 32.0,
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [
                Text('Broken',
                  style: theme.textTheme.titleMedium,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 16.0,
                  children: [
                    Icon(Iconex.broken.home,
                      size: 32.0,
                    ),
                    Icon(Iconex.broken.search,
                      size: 32.0,
                    ),
                    Icon(Iconex.broken.heart,
                      size: 32.0,
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
