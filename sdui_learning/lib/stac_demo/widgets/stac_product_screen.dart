import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import '../data/stac_screen_document.dart';
import '../data/stac_screen_repository.dart';
import '../data/stac_screen_validator.dart';

/// Renders one product-listing screen from Stac JSON.
///
/// The host chooses which document to load. Both layouts are the same
/// [Stac.fromJson] call. The debug controls are not part of the screen JSON.
class StacProductScreen extends StatefulWidget {
  const StacProductScreen({
    super.key,
    required this.repository,
    this.bundledRepository,
    this.validator = const StacScreenValidator(),
  });

  final StacScreenRepository repository;

  /// Local fixtures used when a remote document cannot be loaded.
  final StacScreenRepository? bundledRepository;

  final StacScreenValidator validator;

  @override
  State<StacProductScreen> createState() => _StacProductScreenState();
}

class _StacProductScreenState extends State<StacProductScreen> {
  var _layout = StacLayoutId.grid;
  var _useBundle = false;
  var _previewUnsupported = false;
  var _loading = true;
  var _generation = 0;
  String? _error;
  StacScreenDocument? _document;
  StacScreenValidation? _validation;

  StacScreenRepository get _repository {
    if (_useBundle && widget.bundledRepository != null) {
      return widget.bundledRepository!;
    }
    return widget.repository;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final document = await _repository.load(_layout);
      if (!mounted || generation != _generation) return;
      final validation = widget.validator.validate(
        document.screen,
        rejectUnknownWidgets: !_previewUnsupported,
      );
      setState(() {
        _document = document;
        _validation = validation;
        _loading = false;
      });
    } on StacScreenLoadException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _document = null;
        _validation = null;
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _document = null;
        _validation = null;
        _error = 'The screen could not be loaded.';
        _loading = false;
      });
    }
  }

  void _selectLayout(StacLayoutId layout) {
    setState(() {
      _layout = layout;
      _previewUnsupported = false;
    });
    _load();
  }

  void _useBundledFixture() {
    setState(() => _useBundle = true);
    _load();
  }

  void _previewRawStac() {
    setState(() => _previewUnsupported = true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F1),
      body: Column(
        children: [
          if (kDebugMode)
            _LayoutSelector(
              layout: _layout,
              onSelected: _selectLayout,
              onRefresh: _load,
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return StacStatusView(
        title: 'Screen unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
        secondaryLabel: _canUseBundle ? 'Use bundled layout' : null,
        onSecondary: _canUseBundle ? _useBundledFixture : null,
      );
    }

    final validation = _validation;
    final document = _document;
    if (validation == null || document == null) {
      return StacStatusView(
        title: 'Screen unavailable',
        message: 'Nothing was returned for this layout.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (!validation.isValid) {
      return StacStatusView(
        title: 'This screen cannot be rendered',
        message: validation.message!,
        actionLabel: 'Retry',
        onAction: _load,
        secondaryLabel: kDebugMode ? 'Preview Stac response' : null,
        onSecondary: kDebugMode ? _previewRawStac : null,
      );
    }

    return Builder(
      builder: (context) {
        return Stac.fromJson(document.screen, context) ??
            const StacStatusView(
              title: 'This screen cannot be rendered',
              message: 'Stac did not return a widget for this JSON.',
            );
      },
    );
  }

  bool get _canUseBundle =>
      !_useBundle &&
      widget.bundledRepository != null &&
      !identical(widget.repository, widget.bundledRepository);
}

class _LayoutSelector extends StatelessWidget {
  const _LayoutSelector({
    required this.layout,
    required this.onSelected,
    required this.onRefresh,
  });

  final StacLayoutId layout;
  final ValueChanged<StacLayoutId> onSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1917),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _choice(StacLayoutId.grid, 'Grid'),
              _choice(StacLayoutId.promo, 'Promo'),
              _choice(StacLayoutId.unsupported, 'Unsupported'),
              IconButton(
                key: const Key('stac-refresh'),
                onPressed: onRefresh,
                color: Colors.white,
                tooltip: 'Reload screen JSON',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(StacLayoutId value, String label) {
    final selected = layout == value;
    return TextButton(
      key: Key('stac-layout-${value.name}'),
      onPressed: () => onSelected(value),
      style: TextButton.styleFrom(
        foregroundColor: selected ? const Color(0xFF1C1917) : Colors.white,
        backgroundColor: selected
            ? const Color(0xFFF6F4F1)
            : Colors.transparent,
      ),
      child: Text(label),
    );
  }
}

class StacStatusView extends StatelessWidget {
  const StacStatusView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('stac-retry'),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: Key(
                  secondaryLabel == 'Use bundled layout'
                      ? 'stac-use-fixture'
                      : 'stac-preview-unsupported',
                ),
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
