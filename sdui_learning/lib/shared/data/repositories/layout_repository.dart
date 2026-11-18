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

  /// True when [schemaVersion] is newer than the app supports.
  bool get schemaUnsupported =>
      schemaVersion > LayoutRepository.supportedSchemaVersion;

  String get title => data['title'] as String? ?? docId;

  String? get backgroundHex => data['background'] as String?;

  int get schemaVersion {
    final raw = data['schemaVersion'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 1;
    return 1;
  }

  /// Nested layout tree — model-free.
  Map<String, dynamic>? get root {
    final raw = data['root'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Reusable component templates keyed by stable id.
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
  static const supportedSchemaVersion = 1;
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
          return _fromMap(
            docId,
            snap.data()!,
            fromCache: snap.metadata.isFromCache,
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
    late StreamController<LayoutLoadResult> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    var emitted = false;

    controller = StreamController<LayoutLoadResult>.broadcast(
      onListen: () {
        // Prefer a fast seed while waiting for the first live snapshot.
        unawaited(() async {
          try {
            final seed = await _loadSeed(docId);
            if (!controller.isClosed && !emitted) {
              controller.add(seed);
            }
          } catch (_) {}
        }());

        sub = firestore.collection('screens').doc(docId).snapshots().listen(
          (snap) async {
            if (snap.exists && snap.data() != null) {
              final result = _fromMap(
                docId,
                snap.data()!,
                fromCache: snap.metadata.isFromCache,
              );
              debugPrint(
                '$_tag snapshot ${result.fromCache ? 'CACHE' : 'LIVE'} | '
                'title="${result.title}" | schema=v${result.schemaVersion} | '
                'root.type=${(result.data['root'] as Map?)?['type']}',
              );
              emitted = true;
              if (!controller.isClosed) controller.add(result);
              return;
            }
            debugPrint('$_tag screens/$docId missing → seed');
            emitted = true;
            if (!controller.isClosed) {
              controller.add(await _loadSeed(docId));
            }
          },
          onError: (Object e, StackTrace st) async {
            debugPrint('$_tag screens/$docId stream error: $e\n$st');
            if (!emitted) {
              try {
                final seed = await _loadSeed(docId);
                emitted = true;
                if (!controller.isClosed) controller.add(seed);
                return;
              } catch (_) {}
            }
            if (!controller.isClosed) controller.addError(e, st);
          },
        );
      },
      onCancel: () => sub?.cancel(),
    );

    return controller.stream;
  }

  /// Streams the active festival configured in Firestore `config/active`.
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

  LayoutLoadResult _fromMap(
    String docId,
    Map<String, dynamic> raw, {
    required bool fromCache,
  }) {
    final data = _normalize(raw);
    final result = LayoutLoadResult(
      docId: docId,
      data: data,
      fromCache: fromCache,
    );
    if (result.schemaUnsupported) {
      debugPrint(
        '$_tag unsupported schemaVersion=${result.schemaVersion} '
        '(app supports <= $supportedSchemaVersion)',
      );
    }
    return result;
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
  }

  Future<LayoutLoadResult> _loadSeed(String docId) async {
    final primary = 'assets/sdui/$docId.json';
    try {
      final raw = await rootBundle.loadString(primary);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      debugPrint('$_tag seed loaded $primary');
      return _fromMap(docId, map, fromCache: true);
    } catch (e) {
      debugPrint('$_tag exact seed missing for $docId ($e)');
    }
    throw StateError(
      'No layout seed found for "$docId". '
      'Add assets/sdui/$docId.json or create screens/$docId in Firestore.',
    );
  }
}
