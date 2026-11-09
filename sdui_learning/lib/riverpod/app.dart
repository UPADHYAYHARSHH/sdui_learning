import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/data/repositories/screen_repository.dart';
import 'pages/festival_sdui_page.dart';
import 'providers/screen_providers.dart';

/// Festival SDUI app wired with Riverpod.
class RiverpodSduiApp extends StatelessWidget {
  const RiverpodSduiApp({super.key, required this.repository});

  final ScreenRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [screenRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        title: 'Festival SDUI · Riverpod',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFC45C26),
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        ),
        home: const RiverpodFestivalSduiPage(),
      ),
    );
  }
}
