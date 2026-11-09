import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../sdui/layout/sdui_json.dart';

/// Raw Map-based layout screen (no typed section models).
class LayoutLoadResult {
  const LayoutLoadResult({
    required this.docId,
    required this.data,
    required this.fromCache,
  });

  final String docId;

  /// Full Firestore / asset JSON as a Map.
  final Map<String, dynamic> data;

  final bool fromCache;

  String get title => data['title'] as String? ?? docId;

  String? get backgroundHex => data['background'] as String?;

  /// Nested layout tree — model-free.
  Map<String, dynamic>? get root {
    final raw = data['root'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Reusable component templates keyed by stable id.
  ///
  /// Stored on the same screen document under `components` for backward
  /// compatibility (no new collection required).
  Map<String, Map<String, dynamic>> get components {
    final raw = data['components'];
    if (raw is! Map) return const {};
    final out = <String, Map<String, dynamic>>{};
    raw.forEach((key, value) {
      if (value is Map) {
        out['$key'] = Map<String, dynamic>.from(value);
      }
    });
    return out;
  }

  /// Semantic equality for update detection (ignores Map key insertion order).
  bool isMeaningfullyDifferentFrom(LayoutLoadResult? other) {
    if (other == null) return true;
    if (fromCache != other.fromCache) return true;
    return SduiJson.hasMeaningfulChange(other.data, data);
  }
}

/// Streams `screens/{docId}` as raw JSON for the dynamic layout engine.
class LayoutRepository {
  static const defaultDocId = 'holi';
  static const _tag = '[SDUI][Layout]';

  LayoutRepository({
    FirebaseFirestore? firestore,
    this.firebaseReady = false,
  }) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final bool firebaseReady;

  Future<LayoutLoadResult> load(String docId) async {
    if (firebaseReady && _firestore != null) {
      try {
        final snap = await _firestore.collection('screens').doc(docId).get();
        if (snap.exists && snap.data() != null) {
          debugPrint('$_tag load → Firestore screens/$docId');
          return LayoutLoadResult(
            docId: docId,
            data: _normalize(snap.data()!),
            fromCache: false,
          );
        }
      } catch (e, st) {
        debugPrint('$_tag load error: $e\n$st');
      }
    }
    return _loadSeed(docId);
  }

  /// Live updates when you edit the layout tree in Firebase Console.
  Stream<LayoutLoadResult> watch(String docId) {
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
        final data = _normalize(snap.data()!);
        debugPrint(
          '$_tag snapshot LIVE | title="${data['title']}" | '
          'root.type=${(data['root'] as Map?)?['type']} | '
          'components=${(data['components'] as Map?)?.length ?? 0}',
        );
        return LayoutLoadResult(docId: docId, data: data, fromCache: false);
      }
      debugPrint('$_tag screens/$docId missing → seed');
      return _loadSeed(docId);
    });
  }

  /// Streams the active festival configured in Firestore `config/active`.
  /// Updates in real-time whenever `festivalId` changes in Firebase.
  Stream<LayoutLoadResult> watchActive() {
    final firestore = _firestore;
    if (!firebaseReady || firestore == null) {
      return watch(defaultDocId);
    }

    late StreamController<LayoutLoadResult> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? configSub;
    StreamSubscription<LayoutLoadResult>? screenSub;
    String? currentScreen;

    controller = StreamController<LayoutLoadResult>.broadcast(
      onListen: () {
        configSub = firestore
            .collection('config')
            .doc('active')
            .snapshots()
            .listen(
              (snap) {
                final festivalId =
                    (snap.data()?['festivalId'] as String?)?.trim();
                final target = (festivalId != null && festivalId.isNotEmpty)
                    ? festivalId
                    : defaultDocId;

                if (target == currentScreen && screenSub != null) return;
                currentScreen = target;
                debugPrint('$_tag active festival switched to: $target');

                screenSub?.cancel();
                screenSub = watch(target).listen(
                  (result) {
                    if (!controller.isClosed) {
                      controller.add(result);
                    }
                  },
                  onError: (Object e, StackTrace st) {
                    if (!controller.isClosed) {
                      controller.addError(e, st);
                    }
                  },
                );
              },
              onError: (Object e, StackTrace st) {
                debugPrint('$_tag config/active stream error: $e');
                screenSub?.cancel();
                screenSub = watch(defaultDocId).listen(
                  (result) {
                    if (!controller.isClosed) controller.add(result);
                  },
                  onError: (Object e, StackTrace st) {
                    if (!controller.isClosed) controller.addError(e, st);
                  },
                );
              },
            );
      },
      onCancel: () {
        screenSub?.cancel();
        configSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Deep-copy Maps so callers can safely mutate without corrupting cache.
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
  }

  Future<LayoutLoadResult> _loadSeed(String docId) async {
    final candidates = [
      'assets/sdui/$docId.json',
      'assets/sdui/holi.json',
      'assets/sdui/uttarayan.json',
      'assets/sdui/navratri.json',
      'assets/sdui/diwali.json',
      'assets/sdui/layout_demo.json',
    ];
    for (final path in candidates) {
      try {
        final raw = await rootBundle.loadString(path);
        final map = jsonDecode(raw) as Map<String, dynamic>;
        debugPrint('$_tag seed loaded $path');
        return LayoutLoadResult(docId: docId, data: map, fromCache: true);
      } catch (_) {
        // try next
      }
    }
    throw StateError('No layout seed found for $docId');
  }
}
