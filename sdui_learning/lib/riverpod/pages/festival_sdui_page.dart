import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/ui/festival_sdui_view.dart';
import '../providers/screen_providers.dart';

/// Riverpod version of the festival SDUI screen.
class RiverpodFestivalSduiPage extends ConsumerWidget {
  const RiverpodFestivalSduiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScreen = ref.watch(activeScreenProvider);

    return asyncScreen.when(
      loading: () => const FestivalLoadingView(),
      error: (error, _) => FestivalErrorView(
        error: error,
        onRetry: () => ref.invalidate(activeScreenProvider),
      ),
      data: (result) => FestivalSduiView(
        result: result,
        architectureLabel: 'Riverpod',
        onRetry: () => ref.invalidate(activeScreenProvider),
      ),
    );
  }
}
