/// Runtime configuration for the isolated Stac demo.
///
/// This project has no shared environment file. The optional screen URL is
/// read from a Flutter dart-define so it stays out of source:
///
/// ```
/// flutter run -t lib/main_stac.dart \
///   --dart-define=STAC_SCREEN_URL=https://example.com/sdui/product-listing
/// ```
///
/// When [screenUrl] is null, the demo renders bundled JSON fixtures.
class StacDemoConfig {
  const StacDemoConfig({this.screenUrl, this.configurationError});

  /// Absolute https endpoint that returns a Stac screen document.
  final Uri? screenUrl;

  /// Set when `STAC_SCREEN_URL` is present but not a usable https URL.
  final String? configurationError;

  factory StacDemoConfig.fromEnvironment() {
    return StacDemoConfig.parseScreenUrl(
      const String.fromEnvironment('STAC_SCREEN_URL'),
    );
  }

  /// Parses a screen URL from the environment or a test.
  ///
  /// An empty value means "use bundled fixtures". Anything else must be an
  /// absolute https URL with a host.
  factory StacDemoConfig.parseScreenUrl(String raw) {
    if (raw.isEmpty) {
      return const StacDemoConfig();
    }

    final uri = Uri.tryParse(raw);
    final usable =
        uri != null &&
        uri.isAbsolute &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
    if (!usable) {
      return const StacDemoConfig(
        configurationError:
            'STAC_SCREEN_URL must be an absolute https URL. '
            'Bundled layouts will be used instead.',
      );
    }
    return StacDemoConfig(screenUrl: uri);
  }
}
