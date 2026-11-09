import 'dart:convert';

/// Which bundled product-listing configuration to request.
enum StacLayoutId {
  /// Two-column product grid.
  grid,

  /// Banner, filter chips, and redesigned cards.
  promo,

  /// Same listing with a widget Stac 1.5.0 does not implement.
  unsupported,
}

/// Where a screen document was loaded from.
enum StacScreenOrigin { asset, network }

/// A Stac screen plus the small envelope a backend would return.
///
/// Envelope:
/// ```json
/// {
///   "id": "product_listing",
///   "layout": "grid",
///   "screen": { "type": "scaffold" }
/// }
/// ```
///
/// A bare Stac widget object (`{"type": "scaffold", ...}`) is also accepted.
/// That object is the `screen` field. It must not wrap credentials, tokens,
/// or business rules.
class StacScreenDocument {
  const StacScreenDocument({
    required this.id,
    required this.layout,
    required this.screen,
    required this.origin,
  });

  final String id;
  final String layout;
  final Map<String, dynamic> screen;
  final StacScreenOrigin origin;

  static const maxBytes = 500000;

  /// Parses a backend body or a bundled fixture.
  ///
  /// Throws [FormatException] when the payload is not a JSON object in one
  /// of the two accepted shapes.
  factory StacScreenDocument.parse(
    String body, {
    required StacLayoutId requestedLayout,
    required StacScreenOrigin origin,
  }) {
    if (body.length > maxBytes) {
      throw const FormatException('Screen JSON is too large.');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Screen JSON must be an object.');
    }
    final map = Map<String, dynamic>.from(decoded);

    if (map['screen'] is Map) {
      return StacScreenDocument(
        id: map['id'] is String ? map['id'] as String : 'product_listing',
        layout: map['layout'] is String
            ? map['layout'] as String
            : requestedLayout.name,
        screen: Map<String, dynamic>.from(map['screen'] as Map),
        origin: origin,
      );
    }

    if (map['type'] is String) {
      return StacScreenDocument(
        id: 'product_listing',
        layout: requestedLayout.name,
        screen: map,
        origin: origin,
      );
    }

    throw const FormatException(
      'Screen JSON must be an envelope with a screen object, '
      'or a Stac widget with a type.',
    );
  }
}

/// Failure while reading a screen. [message] is safe to show in the UI.
class StacScreenLoadException implements Exception {
  const StacScreenLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
