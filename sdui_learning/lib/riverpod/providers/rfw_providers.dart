import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/repositories/rfw_repository.dart';

/// Override from [ProviderScope] after Firebase init (see architecture picker / app).
final rfwRepositoryProvider = Provider<RfwRepository>((ref) {
  throw UnimplementedError('Override rfwRepositoryProvider in ProviderScope');
});

/// Live RFW library + data from Firestore `screens/rfw_demo`.
final rfwLayoutProvider = StreamProvider<RfwLoadResult>((ref) {
  final repository = ref.watch(rfwRepositoryProvider);
  return repository.watch();
});
