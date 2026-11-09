import 'package:equatable/equatable.dart';

import '../../shared/data/repositories/screen_repository.dart';

sealed class FestivalScreenState extends Equatable {
  const FestivalScreenState();

  @override
  List<Object?> get props => [];
}

class FestivalScreenLoading extends FestivalScreenState {
  const FestivalScreenLoading();
}

class FestivalScreenReady extends FestivalScreenState {
  const FestivalScreenReady(this.result);

  final ScreenLoadResult result;

  @override
  List<Object?> get props => [result.festivalId, result.fromCache, result.config.title];
}

class FestivalScreenError extends FestivalScreenState {
  const FestivalScreenError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
