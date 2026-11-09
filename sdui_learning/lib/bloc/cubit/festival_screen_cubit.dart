import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/data/repositories/screen_repository.dart';
import 'festival_screen_state.dart';

/// BLoC/Cubit version of the live SDUI subscription.
///
/// Same Firestore cycle as Riverpod:
/// watchActiveScreen() → emit states → BlocBuilder rebuilds UI.
class FestivalScreenCubit extends Cubit<FestivalScreenState> {
  FestivalScreenCubit(this._repository) : super(const FestivalScreenLoading()) {
    _subscribe();
  }

  final ScreenRepository _repository;
  StreamSubscription<ScreenLoadResult>? _subscription;

  void _subscribe() {
    debugPrint('[SDUI][BLoC] Cubit subscribed to watchActiveScreen()');
    _subscription?.cancel();
    emit(const FestivalScreenLoading());

    _subscription = _repository.watchActiveScreen().listen(
      (result) {
        debugPrint(
          '[SDUI][BLoC] emit Ready ← festival=${result.festivalId} '
          'source=${result.fromCache ? "OFFLINE" : "LIVE"}',
        );
        emit(FestivalScreenReady(result));
      },
      onError: (Object error, StackTrace st) {
        debugPrint('[SDUI][BLoC] stream error: $error\n$st');
        emit(FestivalScreenError('$error'));
      },
    );
  }

  /// Re-attach the Firestore stream (Retry).
  void retry() => _subscribe();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
