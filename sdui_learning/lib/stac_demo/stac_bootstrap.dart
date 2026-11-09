import 'package:stac/stac.dart';

import 'widgets/product_discount_badge_parser.dart';

/// Registers Stac 1.5.0 parsers for this demo.
///
/// Call this before [Stac.fromJson]. The cache strategy is `networkOnly`
/// so Stac Cloud screens are not written to disk. This demo does not use
/// `Stac(routeName:)`, and its own repository does not cache screen JSON.
Future<void> initializeStacDemo() {
  return Stac.initialize(
    parsers: const [ProductDiscountBadgeParser()],
    showErrorWidgets: true,
    cacheConfig: const StacCacheConfig(strategy: StacCacheStrategy.networkOnly),
  );
}
