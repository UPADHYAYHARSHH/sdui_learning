import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/ui/festival_sdui_view.dart';
import '../cubit/festival_screen_cubit.dart';
import '../cubit/festival_screen_state.dart';

/// BLoC version of the festival SDUI screen.
class BlocFestivalSduiPage extends StatelessWidget {
  const BlocFestivalSduiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FestivalScreenCubit, FestivalScreenState>(
      builder: (context, state) {
        return switch (state) {
          FestivalScreenLoading() => const FestivalLoadingView(),
          FestivalScreenError(:final message) => FestivalErrorView(
              error: message,
              onRetry: () => context.read<FestivalScreenCubit>().retry(),
            ),
          FestivalScreenReady(:final result) => FestivalSduiView(
              result: result,
              architectureLabel: 'BLoC',
              onRetry: () => context.read<FestivalScreenCubit>().retry(),
            ),
        };
      },
    );
  }
}
