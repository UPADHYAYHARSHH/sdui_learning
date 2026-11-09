import 'package:flutter/material.dart';

import 'stac_demo/stac_bootstrap.dart';
import 'stac_demo/stac_demo_app.dart';
import 'stac_demo/stac_demo_config.dart';

/// Isolated Stac entry point. `lib/main.dart` is unchanged.
///
/// ```
/// flutter run -t lib/main_stac.dart
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeStacDemo();
  runApp(StacDemoApp(config: StacDemoConfig.fromEnvironment()));
}
