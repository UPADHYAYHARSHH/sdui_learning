import 'package:flutter/material.dart';

import 'data/stac_screen_repository.dart';
import 'stac_demo_config.dart';
import 'widgets/stac_product_screen.dart';

/// Separate Stac application. It does not boot Firebase or the existing SDUI.
class StacDemoApp extends StatelessWidget {
  const StacDemoApp({
    super.key,
    required this.config,
    this.repository,
    this.bundledRepository = const AssetStacScreenRepository(),
  });

  final StacDemoConfig config;
  final StacScreenRepository? repository;
  final StacScreenRepository bundledRepository;

  @override
  Widget build(BuildContext context) {
    final remote = config.screenUrl;
    final screenRepository =
        repository ??
        (remote == null
            ? bundledRepository
            : NetworkStacScreenRepository(endpoint: remote));

    return MaterialApp(
      title: 'Stac SDUI demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F3A34)),
      ),
      home: Column(
        children: [
          if (config.configurationError != null)
            Material(
              color: const Color(0xFFFEF3C7),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(config.configurationError!),
                ),
              ),
            ),
          Expanded(
            child: StacProductScreen(
              repository: screenRepository,
              bundledRepository: bundledRepository,
            ),
          ),
        ],
      ),
    );
  }
}
