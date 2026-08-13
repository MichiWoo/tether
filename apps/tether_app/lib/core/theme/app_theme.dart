import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dracula_palette.dart';

/// Tema claro de Tether (Alucard Classic, Dracula light).
ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: buildAlucardColorScheme(),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
  );
}

/// Tema oscuro de Tether (Dracula Classic).
ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: buildDraculaColorScheme(),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
  );
}
