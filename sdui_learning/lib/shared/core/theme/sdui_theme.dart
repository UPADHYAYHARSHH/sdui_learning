import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/sdui_models.dart';

ThemeData buildSduiTheme(SduiThemeConfig config) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: config.primary,
      primary: config.primary,
      secondary: config.secondary,
      surface: config.surface,
      onPrimary: config.onPrimary,
      onSurface: config.onBackground,
      brightness: _brightnessFor(config.background),
    ),
    scaffoldBackgroundColor: config.background,
  );

  return base.copyWith(
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: config.onBackground,
      displayColor: config.onBackground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: config.background,
      foregroundColor: config.onBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        color: config.onBackground,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: config.primary,
        foregroundColor: config.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Brightness _brightnessFor(Color background) {
  return ThemeData.estimateBrightnessForColor(background);
}
