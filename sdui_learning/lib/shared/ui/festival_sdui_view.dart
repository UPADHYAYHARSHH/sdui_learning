import 'package:flutter/material.dart';

import '../core/theme/sdui_theme.dart';
import '../data/repositories/screen_repository.dart';
import '../sdui/layout/dynamic_layout_builder.dart';
import '../sdui/registry/widget_registry.dart';

/// Shared SDUI renderer used by both Riverpod and BLoC directories.
///
/// State management only supplies [ScreenLoadResult]; this widget builds UI.
class FestivalSduiView extends StatelessWidget {
  const FestivalSduiView({super.key, required this.result, required this.architectureLabel, this.onRetry});

  final ScreenLoadResult result;
  final String architectureLabel;
  final VoidCallback? onRetry;

  static const _registry = SduiWidgetRegistry();

  @override
  Widget build(BuildContext context) {
    final config = result.config;
    final theme = buildSduiTheme(config.theme);

    if (config.root != null) {
      final builder = DynamicLayoutBuilder(components: config.components);
      final canPop = Navigator.of(context).canPop();
      return Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F5F0),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: builder.build(config.root),
              ),
              if (canPop)
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
        ),
      );
    }

    return Theme(
      data: theme,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(config.title),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      result.fromCache ? 'Offline · ${result.festivalId}' : 'Live · ${result.festivalId}',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text('Architecture: $architectureLabel', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
            ),
            SliverList(delegate: SliverChildListDelegate(_registry.buildAll(config.sections))),
          ],
        ),
      ),
    );
  }
}

/// Shared loading / error shells for both architectures.
class FestivalLoadingView extends StatelessWidget {
  const FestivalLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class FestivalErrorView extends StatelessWidget {
  const FestivalErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Festival')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load screen', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              if (onRetry != null) ...[const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text('Retry'))],
            ],
          ),
        ),
      ),
    );
  }
}
