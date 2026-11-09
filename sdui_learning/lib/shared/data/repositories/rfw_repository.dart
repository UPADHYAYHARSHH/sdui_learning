import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Firestore / asset payload for an RFW remote library.
class RfwLoadResult {
  const RfwLoadResult({
    required this.docId,
    required this.title,
    required this.library,
    required this.data,
    required this.fromCache,
  });

  final String docId;
  final String title;

  /// RFW text library (`.rfwtxt` style). Parsed with [parseLibraryFile].
  final String library;

  /// DynamicContent root map (e.g. `{ "ui": { "title": "..." } }`).
  final Map<String, Object?> data;

  final bool fromCache;
}

/// Streams `screens/rfw_demo` for RFW library + data.
///
/// Document fields:
/// - `title` (string)
/// - `library` (string) — RFW text library defining `widget root = ...`
/// - `data` (map) — bound as RFW `data.*`
class RfwRepository {
  static const defaultDocId = 'rfw_demo';
  static const _tag = '[SDUI][RFW]';

  RfwRepository({
    FirebaseFirestore? firestore,
    this.firebaseReady = false,
  }) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final bool firebaseReady;

  Stream<RfwLoadResult> watch([String docId = defaultDocId]) {
    final firestore = _firestore;
    if (!firebaseReady || firestore == null) {
      debugPrint('$_tag watch OFFLINE → asset seed');
      return Stream.fromFuture(_loadSeed(docId));
    }

    debugPrint('$_tag watch LIVE → screens/$docId');
    return firestore.collection('screens').doc(docId).snapshots().asyncMap((
      snap,
    ) async {
      if (snap.exists && snap.data() != null) {
        final parsed = _fromMap(docId, snap.data()!, fromCache: false);
        if (parsed != null) {
          debugPrint(
            '$_tag snapshot LIVE | title="${parsed.title}" | '
            'libraryChars=${parsed.library.length}',
          );
          return parsed;
        }
        debugPrint(
          '$_tag screens/$docId exists but missing/empty "library" field',
        );
      } else {
        debugPrint('$_tag screens/$docId missing → seed (Firebase is live)');
      }
      // Firebase is connected; seed is only a temporary fallback.
      final seed = await _loadSeed(docId);
      return RfwLoadResult(
        docId: seed.docId,
        title: seed.title,
        library: seed.library,
        data: seed.data,
        fromCache: false,
      );
    });
  }

  RfwLoadResult? _fromMap(
    String docId,
    Map<String, dynamic> raw, {
    required bool fromCache,
  }) {
    final library = raw['library'] as String?;
    if (library == null || library.trim().isEmpty) return null;

    final dataRaw = raw['data'];
    final data = <String, Object?>{};
    if (dataRaw is Map) {
      dataRaw.forEach((key, value) {
        data['$key'] = _toRfwValue(value);
      });
    }

    return RfwLoadResult(
      docId: docId,
      title: raw['title'] as String? ?? docId,
      library: library,
      data: data,
      fromCache: fromCache,
    );
  }

  /// RFW DynamicContent accepts maps/lists/nums/strings/bools (no DateTime etc.).
  Object? _toRfwValue(Object? value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    if (value is Map) {
      final out = <String, Object?>{};
      value.forEach((k, v) => out['$k'] = _toRfwValue(v));
      return out;
    }
    if (value is List) {
      return value.map(_toRfwValue).toList();
    }
    return value.toString();
  }

  Future<RfwLoadResult> _loadSeed(String docId) async {
    final candidates = ['assets/sdui/$docId.json', 'assets/sdui/rfw_demo.json'];
    for (final path in candidates) {
      try {
        final raw = await rootBundle.loadString(path);
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final parsed = _fromMap(docId, map, fromCache: true);
        if (parsed != null) {
          debugPrint('$_tag seed loaded $path');
          return parsed;
        }
      } catch (_) {
        // try next
      }
    }
    throw StateError('No RFW seed found for $docId');
  }
}
