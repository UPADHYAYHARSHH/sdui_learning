import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'stac_screen_document.dart';

/// Loads a Stac screen document.
///
/// ## Backend contract
///
/// There is no screen endpoint in this project today. The existing SDUI
/// data lives in Firestore documents shaped for `DynamicLayoutBuilder` and
/// RFW, not for Stac. Do not reuse those documents.
///
/// When a backend is ready, serve `GET {STAC_SCREEN_URL}?layout=grid|promo`.
/// The URL is passed with `--dart-define=STAC_SCREEN_URL=https://...`.
/// This client appends `layout` and does not send credentials.
///
/// Response `200` `application/json`, at most 500 KB:
///
/// ```json
/// {
///   "id": "product_listing",
///   "layout": "grid",
///   "screen": { "type": "scaffold", "body": {} }
/// }
/// ```
///
/// `screen` is a Stac 1.5.0 widget tree (`type`, not a custom schema).
/// A bare widget object is also accepted. The body must not include API
/// keys, tokens, passwords, or payment data. Authentication and business
/// rules stay on the server.
///
/// This repository does not cache responses. Stac's own cache applies to
/// `Stac(routeName:)`, which this demo does not use.
abstract class StacScreenRepository {
  const StacScreenRepository();

  Future<StacScreenDocument> load(StacLayoutId layout);
}

/// Bundled fixtures under `assets/sdui/stac/`.
class AssetStacScreenRepository extends StacScreenRepository {
  const AssetStacScreenRepository();

  static const gridAsset = 'assets/sdui/stac/product_listing_grid.json';
  static const promoAsset = 'assets/sdui/stac/product_listing_promo.json';
  static const unsupportedAsset =
      'assets/sdui/stac/product_listing_unsupported.json';

  @override
  Future<StacScreenDocument> load(StacLayoutId layout) async {
    final path = switch (layout) {
      StacLayoutId.grid => gridAsset,
      StacLayoutId.promo => promoAsset,
      StacLayoutId.unsupported => unsupportedAsset,
    };
    try {
      // cache: false keeps the load future in the caller's zone. The asset
      // bundle otherwise reuses a future cached by an earlier caller.
      final body = await rootBundle.loadString(path, cache: false);
      return StacScreenDocument.parse(
        body,
        requestedLayout: layout,
        origin: StacScreenOrigin.asset,
      );
    } on FormatException {
      throw const StacScreenLoadException(
        'The bundled screen JSON is not valid.',
      );
    } catch (_) {
      throw const StacScreenLoadException(
        'The bundled screen could not be read.',
      );
    }
  }
}

/// Reads the raw response body for [NetworkStacScreenRepository].
typedef StacRemoteLoader = Future<String> Function(Uri uri);

/// GET a screen from the configured https endpoint.
///
/// Redirects are not followed. Non-200 responses become a load error and
/// the response body is discarded.
class NetworkStacScreenRepository extends StacScreenRepository {
  const NetworkStacScreenRepository({
    required this.endpoint,
    this.loader = loadStacScreenBody,
  });

  final Uri endpoint;
  final StacRemoteLoader loader;

  @override
  Future<StacScreenDocument> load(StacLayoutId layout) async {
    final uri = endpoint.replace(
      queryParameters: {...endpoint.queryParameters, 'layout': layout.name},
    );
    try {
      final body = await loader(uri);
      return StacScreenDocument.parse(
        body,
        requestedLayout: layout,
        origin: StacScreenOrigin.network,
      );
    } on StacScreenLoadException {
      rethrow;
    } on FormatException {
      throw const StacScreenLoadException(
        'The server did not return Stac screen JSON.',
      );
    } catch (_) {
      throw const StacScreenLoadException('The screen could not be loaded.');
    }
  }
}

/// HTTPS GET used when no test loader is injected.
///
/// Uses `dart:io`, so this loader is for mobile and desktop runs of
/// `lib/main_stac.dart`.
Future<String> loadStacScreenBody(Uri uri) async {
  if (uri.scheme != 'https') {
    throw const StacScreenLoadException('Screen URL must use https.');
  }

  final client = HttpClient();
  try {
    client.connectionTimeout = const Duration(seconds: 10);
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw StacScreenLoadException(
        'Screen request failed (HTTP ${response.statusCode}).',
      );
    }
    final bytes = await response.fold<List<int>>(<int>[], (previous, chunk) {
      previous.addAll(chunk);
      if (previous.length > StacScreenDocument.maxBytes) {
        throw const StacScreenLoadException('Screen response is too large.');
      }
      return previous;
    });
    return utf8.decode(bytes);
  } on StacScreenLoadException {
    rethrow;
  } on HttpException {
    throw const StacScreenLoadException('Screen request failed.');
  } catch (_) {
    throw const StacScreenLoadException('Screen request failed.');
  } finally {
    client.close(force: true);
  }
}
