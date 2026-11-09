import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/repositories/screen_repository.dart';

/// Provided from [RiverpodSduiApp] via override (created in main after Firebase init).
final screenRepositoryProvider = Provider<ScreenRepository>((ref) {
  throw UnimplementedError(
    'Override screenRepositoryProvider in ProviderScope',
  );
});

/// Live SDUI stream — same Firestore cycle as BLoC, exposed as Riverpod StreamProvider.
///
/// Cycle: watchActiveScreen() → config/active snapshots → screens/{id} snapshots
/// → AsyncValue.data → UI rebuild.
final activeScreenProvider = StreamProvider<ScreenLoadResult>((ref) {
  final repository = ref.watch(screenRepositoryProvider);
  return repository.watchActiveScreen();
});
