import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dracula_palette.dart';

/// Tema claro de Tether (Alucard Classic, Dracula light).
ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: buildAlucardColorScheme(),
  );
  return base.copyWith(textTheme: _textTheme(base));
}

/// Tema oscuro de Tether (Dracula Classic).
ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: buildDraculaColorScheme(),
  );
  return base.copyWith(textTheme: _textTheme(base));
}

TextTheme _textTheme(ThemeData base) {
  final text = GoogleFonts.soraTextTheme(base.textTheme);
  return text.copyWith(
    // Títulos con la fuente display, más anchos y con tracking ajustado.
    displayLarge: text.displayLarge?.copyWith(letterSpacing: -1.2),
    displayMedium: text.displayMedium?.copyWith(letterSpacing: -0.8),
    headlineLarge: text.headlineLarge?.copyWith(letterSpacing: -0.6),
    headlineMedium: text.headlineMedium?.copyWith(letterSpacing: -0.4),
    titleLarge: text.titleLarge?.copyWith(letterSpacing: -0.3),
  );
}
