import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/layout_repository.dart';
import '../sdui/layout/dynamic_layout_builder.dart';

/// Streams a model-free layout tree from Firestore `screens/layout_demo`.
///
/// Edit the JSON in Firebase (e.g. change column/row → grid) — UI updates live.
/// Semantic JSON comparison skips unnecessary rebuilds; the last valid layout
/// is kept if a bad snapshot arrives.
class DynamicLayoutPage extends StatefulWidget {
  const DynamicLayoutPage({
    super.key,
    required this.repository,
    this.docId,
  });

  final LayoutRepository repository;
  final String? docId;

  @override
  State<DynamicLayoutPage> createState() => _DynamicLayoutPageState();
}

class _DynamicLayoutPageState extends State<DynamicLayoutPage> {
  StreamSubscription<LayoutLoadResult>? _sub;
  LayoutLoadResult? _result;
  Object? _error;
  DynamicLayoutBuilder _builder = DynamicLayoutBuilder();

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    final targetDoc = widget.docId;
    final isExplicit = targetDoc != null && targetDoc.isNotEmpty && targetDoc != 'active';
    debugPrint(
      '[SDUI][Layout] UI subscribing to ${isExplicit ? 'screens/$targetDoc' : 'config/active (dynamic festival)'}',
    );

    final stream = isExplicit
        ? widget.repository.watch(targetDoc)
        : widget.repository.watchActive();

    _sub = stream.listen(
          (result) {
            if (!mounted) return;

            // Reject empty/broken roots when we already have a good layout.
            final root = result.root;
            if ((root == null || root.isEmpty) && _result?.root != null) {
              debugPrint(
                '[SDUI][Layout] Ignoring empty root; keeping previous layout',
              );
              return;
            }

            // Semantic compare — skip rebuild for equivalent JSON (key order/format).
            if (_result != null &&
                !_result!.isMeaningfullyDifferentFrom(result)) {
              debugPrint(
                '[SDUI][Layout] No meaningful JSON change — skip rebuild',
              );
              return;
            }

            setState(() {
              _result = result;
              // New builder so component template changes invalidate prior refs.
              _builder = DynamicLayoutBuilder(components: result.components);
              _error = null;
            });
          },
          onError: (Object e, StackTrace st) {
            debugPrint('[SDUI][Layout] UI error: $e\n$st');
            if (!mounted) return;
            // Keep prior valid layout on stream errors.
            if (_result != null) {
              debugPrint(
                '[SDUI][Layout] Keeping previous layout after stream error',
              );
              return;
            }
            setState(() => _error = e);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dynamic Layout')),
        body: Center(child: Text('$_error')),
      );
    }

    if (_result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final result = _result!;
    final showAppBar = result.data['showAppBar'] == true;
    final bg = _parseColor(result.backgroundHex) ?? const Color(0xFFF7F5F0);
    final bottomNavRaw = result.data['bottomNav'];
    final bottomNavWidget = bottomNavRaw is Map
        ? _builder.build(Map<String, dynamic>.from(bottomNavRaw))
        : null;

    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: bg,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: bg,
              title: Text(result.title),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      result.fromCache
                          ? 'Offline · map SDUI'
                          : 'Live · map SDUI',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFE8B84B),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      bottomNavigationBar: bottomNavWidget,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: _builder.build(result.root),
                ),
              );
            },
          ),
          if (!showAppBar && canPop)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    if (cleaned.length != 8) return null;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}
