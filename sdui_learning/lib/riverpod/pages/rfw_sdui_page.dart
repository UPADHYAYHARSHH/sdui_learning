import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfw/formats.dart' show parseLibraryFile;
import 'package:rfw/rfw.dart';

import '../../shared/data/repositories/rfw_repository.dart';
import '../providers/rfw_providers.dart';

/// Riverpod + RFW demo: remote library text from Firestore drives the UI.
///
/// Edit `screens/rfw_demo.library` (or `data`) in Firebase — RFW rebuilds live.
class RiverpodRfwSduiPage extends ConsumerStatefulWidget {
  const RiverpodRfwSduiPage({super.key});

  @override
  ConsumerState<RiverpodRfwSduiPage> createState() =>
      _RiverpodRfwSduiPageState();
}

class _RiverpodRfwSduiPageState extends ConsumerState<RiverpodRfwSduiPage> {
  static const _coreWidgets = LibraryName(<String>['core', 'widgets']);
  static const _coreMaterial = LibraryName(<String>['core', 'material']);
  static const _main = LibraryName(<String>['main']);

  final Runtime _runtime = Runtime();
  final DynamicContent _data = DynamicContent();

  String? _appliedLibrary;
  Object? _parseError;

  @override
  void initState() {
    super.initState();
    _runtime.update(_coreWidgets, createCoreWidgets());
    _runtime.update(_coreMaterial, createMaterialWidgets());
  }

  /// Runtime / DynamicContent notify [RemoteWidget] themselves.
  void _applyResult(RfwLoadResult result) {
    if (_appliedLibrary != result.library) {
      try {
        _runtime.update(_main, parseLibraryFile(result.library));
        _appliedLibrary = result.library;
        _parseError = null;
        debugPrint(
          '[SDUI][RFW] library applied (${result.library.length} chars)',
        );
      } catch (e, st) {
        debugPrint('[SDUI][RFW] library parse failed: $e\n$st');
        if (_appliedLibrary == null) {
          _parseError = e;
        }
      }
    }

    for (final entry in result.data.entries) {
      final value = entry.value;
      if (value != null) {
        _data.update(entry.key, value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RfwLoadResult>>(rfwLayoutProvider, (_, next) {
      next.whenData((result) {
        final before = _appliedLibrary;
        final beforeErr = _parseError;
        _applyResult(result);
        if (before != _appliedLibrary || beforeErr != _parseError) {
          setState(() {});
        }
      });
    });

    final async = ref.watch(rfwLayoutProvider);

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('RFW · Riverpod')),
        body: Center(child: Text('$e')),
      ),
      data: (result) {
        // First frame: listen may not have fired yet.
        if (_appliedLibrary == null && _parseError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyResult(result);
            setState(() {});
          });
        }

        if (_parseError != null && _appliedLibrary == null) {
          return Scaffold(
            appBar: AppBar(title: Text(result.title)),
            body: Center(child: Text('RFW parse error: $_parseError')),
          );
        }

        if (_appliedLibrary == null) {
          return Scaffold(
            appBar: AppBar(title: Text(result.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F12),
          body: Stack(
            children: [
              Positioned.fill(
                child: RemoteWidget(
                  runtime: _runtime,
                  data: _data,
                  widget: const FullyQualifiedWidgetName(_main, 'root'),
                  onEvent: (name, args) {
                    debugPrint('[SDUI][RFW] event=$name args=$args');
                  },
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 12,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      result.fromCache ? 'Offline · RFW' : 'Live · RFW',
                      style: const TextStyle(
                        color: Color(0xFFE8B84B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
