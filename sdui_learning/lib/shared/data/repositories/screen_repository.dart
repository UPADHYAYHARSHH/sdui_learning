import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sdui_models.dart';
import '../seeds/local_seed_loader.dart';

/// One emission of the SDUI stream: parsed screen JSON + metadata.
class ScreenLoadResult {
  const ScreenLoadResult({required this.config, required this.fromCache, required this.festivalId});

  /// Theme + sections ready for the widget registry.
  final SduiScreenConfig config;

  /// true = loaded from local assets (offline fallback).
  /// false = loaded from live Firestore.
  final bool fromCache;

  /// Which festival this result belongs to: diwali | navratri | holi.
  final String festivalId;
}

/// Loads festival SDUI JSON from Firestore (live) or asset seeds (fallback).
///
/// Firestore layout:
/// - `config/active`  → `{ festivalId: "diwali" }`  (which UI to show)
/// - `screens/{id}`   → full screen JSON (theme + sections)
class ScreenRepository {
  static const defaultFestivalId = 'diwali';
  static const activeConfigPath = 'config/active';
  static const _tag = '[SDUI]';

  ScreenRepository({
    FirebaseFirestore? firestore,
    LocalSeedLoader? seedLoader,
    this.firebaseReady = false,
  })  : _firestore = firestore,
        _seedLoader = seedLoader ?? const LocalSeedLoader();

  final FirebaseFirestore? _firestore;
  final LocalSeedLoader _seedLoader;

  /// When false, all reads use local JSON under assets/sdui/.
  final bool firebaseReady;

  /// One-shot fetch (no live updates). Used for Retry / offline helpers.
  Future<ScreenLoadResult> loadScreen(String festivalId) async {
    final id = _normalizeFestivalId(festivalId);
    debugPrint('$_tag loadScreen($id) firebaseReady=$firebaseReady');

    if (firebaseReady && _firestore != null) {
      try {
        // .get() = ask Firestore once, then done (not a stream).
        final snap = await _firestore.collection('screens').doc(id).get();
        if (snap.exists && snap.data() != null) {
          debugPrint('$_tag loadScreen → Firestore hit screens/$id');
          return ScreenLoadResult(config: SduiScreenConfig.fromJson(snap.data()!), fromCache: false, festivalId: id);
        }
        debugPrint('$_tag loadScreen → screens/$id missing, using seed');
      } catch (e, st) {
        debugPrint('$_tag loadScreen Firestore error: $e\n$st');
      }
    }

    final seed = await _seedLoader.load(id);
    debugPrint('$_tag loadScreen → local seed $id');
    return ScreenLoadResult(config: seed, fromCache: true, festivalId: id);
  }

  /// Live SDUI stream used by the home page.
  ///
  /// Streaming cycle (runs until the UI cancels the subscription):
  ///
  /// 1. UI calls `.listen(...)` → [StreamController.onListen] runs.
  /// 2. We open a long-lived listener on `config/active` via `.snapshots()`.
  /// 3. Each time `festivalId` changes (e.g. diwali → holi):
  ///    - cancel the previous `screens/{oldId}` listener
  ///    - open a new listener on `screens/{newId}`
  /// 4. Each screen snapshot is parsed to [ScreenLoadResult] and pushed with
  ///    `controller.add(...)` → UI `setState` rebuilds.
  /// 5. When the page is disposed, UI cancels listen → [onCancel] tears down
  ///    both Firestore listeners.
  ///
  /// Why not use `asyncExpand`?
  /// Firestore `.snapshots()` never completes. `asyncExpand` would wait forever
  /// on the first screen stream and ignore later `festivalId` changes.
  /// So we manually switch listeners (switchMap pattern).
  Stream<ScreenLoadResult> watchActiveScreen() {
    final firestore = _firestore;
    if (!firebaseReady || firestore == null) {
      debugPrint(
        '$_tag watchActiveScreen OFFLINE — no Firebase. '
        'Serving local seed "$defaultFestivalId" (stream not live).',
      );
      // Single future wrapped as a stream — one emission, then done.
      return Stream.fromFuture(loadScreen(defaultFestivalId));
    }

    debugPrint(
      '$_tag watchActiveScreen LIVE — listening to config/active '
      'then screens/{festivalId} (switchMap)',
    );

    // Bridge: Firestore callbacks → a Dart Stream the UI can listen to.
    late final StreamController<ScreenLoadResult> controller;

    // Outer subscription: which festival is active?
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? activeSub;

    // Inner subscription: JSON for that festival screen.
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? screenSub;

    // Tracks the festival we are currently attached to (avoid duplicate attaches).
    String? currentFestivalId;

    /// Cancel old screen listener (if any) and attach to screens/[festivalId].
    Future<void> attachScreenListener(String festivalId) async {
      // Stop listening to the previous festival document.
      await screenSub?.cancel();
      screenSub = null;
      currentFestivalId = festivalId;

      debugPrint('$_tag attaching listener → screens/$festivalId');

      // .snapshots() keeps a WebSocket-style connection open.
      // Callback fires on first load AND on every later edit in Firebase Console.
      screenSub = firestore
          .collection('screens')
          .doc(festivalId)
          .snapshots()
          .listen(
            (snap) async {
              if (controller.isClosed) return;
              // Ignore late events from a listener we already replaced.
              if (currentFestivalId != festivalId) return;

              if (snap.exists && snap.data() != null) {
                final data = snap.data()!;
                debugPrint(
                  '$_tag screens/$festivalId snapshot | LIVE | '
                  'title="${data['title']}" | '
                  'sections=${(data['sections'] as List?)?.length ?? 0}',
                );
                // Push to UI stream → FestivalSduiPage.listen → setState.
                controller.add(ScreenLoadResult(config: SduiScreenConfig.fromJson(data), fromCache: false, festivalId: festivalId));
                return;
              }

              // Document missing in Firestore → fall back to asset JSON.
              debugPrint('$_tag screens/$festivalId missing — local seed fallback');
              final seed = await _seedLoader.load(festivalId);
              if (controller.isClosed || currentFestivalId != festivalId) return;
              controller.add(ScreenLoadResult(config: seed, fromCache: true, festivalId: festivalId));
            },
            onError: (Object e, StackTrace st) {
              debugPrint('$_tag screens/$festivalId ERROR: $e\n$st');
              if (!controller.isClosed) controller.addError(e, st);
            },
          );
    }

    controller = StreamController<ScreenLoadResult>(
      // Runs once when the UI starts listening.
      onListen: () {
        // Outer live listener: config/active.festivalId
        activeSub = firestore
            .collection('config')
            .doc('active')
            .snapshots()
            .listen(
              (activeSnap) {
                final exists = activeSnap.exists;
                final raw = activeSnap.data()?['festivalId'] as String?;
                final festivalId = _normalizeFestivalId(raw);

                debugPrint(
                  '$_tag config/active snapshot | exists=$exists | '
                  'raw festivalId="$raw" → using "$festivalId"',
                );

                // Same festival again (e.g. unrelated field edit) → keep current listener.
                if (festivalId == currentFestivalId && screenSub != null) {
                  debugPrint('$_tag festivalId unchanged ($festivalId) — keep screen listener');
                  return;
                }

                // Festival switched (diwali → holi) → swap screen listener.
                unawaited(attachScreenListener(festivalId));
              },
              onError: (Object e, StackTrace st) {
                debugPrint('$_tag config/active ERROR: $e\n$st');
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
      },
      // Runs when UI cancels (page dispose / hot restart).
      onCancel: () async {
        debugPrint('$_tag watchActiveScreen cancelled — cleaning listeners');
        await screenSub?.cancel();
        await activeSub?.cancel();
        screenSub = null;
        activeSub = null;
      },
    );

    return controller.stream;
  }

  /// Only allow known festival ids; anything else falls back to Diwali.
  String _normalizeFestivalId(String? raw) {
    final id = raw?.trim().toLowerCase() ?? '';
    if (id == 'navratri' || id == 'diwali' || id == 'holi') {
      return id;
    }
    if (id.isNotEmpty) {
      debugPrint('$_tag unknown festivalId "$raw" — falling back to "$defaultFestivalId"');
    }
    return defaultFestivalId;
  }
}
