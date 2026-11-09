import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/data/repositories/screen_repository.dart';
import 'cubit/festival_screen_cubit.dart';
import 'pages/festival_sdui_page.dart';

/// Festival SDUI app wired with flutter_bloc (Cubit).
class BlocSduiApp extends StatelessWidget {
  const BlocSduiApp({super.key, required this.repository});

  final ScreenRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FestivalScreenCubit(repository),
      child: MaterialApp(
        title: 'Festival SDUI · BLoC',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7B1E3A),
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        ),
        home: const BlocFestivalSduiPage(),
      ),
    );
  }
}
