import 'package:flutter/material.dart';

/// Paleta oficial de Dracula Theme (https://draculatheme.com/spec).
///
/// Dos variantes: **Dracula Classic** (oscura) y **Alucard Classic** (clara).
abstract final class DraculaPalette {
  // Dracula Classic (dark)
  static const background = Color(0xFF282A36);
  static const currentLine = Color(0xFF6272A4);
  static const selection = Color(0xFF44475A);
  static const foreground = Color(0xFFF8F8F2);
  static const comment = Color(0xFF6272A4);
  static const red = Color(0xFFFF5555);
  static const orange = Color(0xFFFFB86C);
  static const yellow = Color(0xFFF1FA8C);
  static const green = Color(0xFF50FA7B);
  static const cyan = Color(0xFF8BE9FD);
  static const purple = Color(0xFFBD93F9);
  static const pink = Color(0xFFFF79C6);

  // Superficies (dark)
  static const bgLighter = Color(0xFF424450);
  static const bgLight = Color(0xFF343746);
  static const bgDark = Color(0xFF21222C);
  static const bgDarker = Color(0xFF191A21);

  // Alucard Classic (light)
  static const alucardBackground = Color(0xFFFFFBEB);
  static const alucardForeground = Color(0xFF1F1F1F);
  static const alucardComment = Color(0xFF6C664B);
  static const alucardSelection = Color(0xFFCFCFDE);
  static const alucardRed = Color(0xFFCB3A2A);
  static const alucardGreen = Color(0xFF14710A);
  static const alucardCyan = Color(0xFF036A96);
  static const alucardPurple = Color(0xFF644AC9);
  static const alucardPink = Color(0xFFA3144D);
  static const alucardYellow = Color(0xFF846E15);

  // Superficies (light)
  static const alucardFloating = Color(0xFFEFEDDC);
  static const alucardLight = Color(0xFFDEDCCF);
}

/// Mezcla [color] sobre [base] con [alpha] (para derivar contenedores tonales
/// sin salir de la paleta).
Color _blend(Color color, Color base, double alpha) =>
    Color.alphaBlend(color.withOpacity(alpha), base);

/// Esquema Material 3 oscuro a partir de Dracula Classic.
ColorScheme buildDraculaColorScheme() {
  const bg = DraculaPalette.background;
  const fg = DraculaPalette.foreground;

  return const ColorScheme(
    brightness: Brightness.dark,
    primary: DraculaPalette.purple,
    onPrimary: DraculaPalette.bgDarker,
    primaryContainer: DraculaPalette.selection,
    onPrimaryContainer: DraculaPalette.foreground,
    secondary: DraculaPalette.cyan,
    onSecondary: DraculaPalette.bgDark,
    secondaryContainer: DraculaPalette.bgLight,
    onSecondaryContainer: DraculaPalette.foreground,
    tertiary: DraculaPalette.pink,
    onTertiary: DraculaPalette.bgDark,
    tertiaryContainer: DraculaPalette.bgLight,
    onTertiaryContainer: DraculaPalette.foreground,
    error: DraculaPalette.red,
    onError: DraculaPalette.bgDarker,
    errorContainer: Color(0xFF5A2D2D),
    onErrorContainer: Color(0xFFFFD7D2),
    surface: bg,
    onSurface: fg,
    surfaceContainerLowest: DraculaPalette.bgDarker,
    surfaceContainerLow: DraculaPalette.bgDark,
    surfaceContainer: DraculaPalette.background,
    surfaceContainerHigh: DraculaPalette.bgLight,
    surfaceContainerHighest: DraculaPalette.selection,
    onSurfaceVariant: DraculaPalette.comment,
    outline: DraculaPalette.currentLine,
    outlineVariant: DraculaPalette.bgLight,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: DraculaPalette.foreground,
    onInverseSurface: DraculaPalette.bgDark,
    inversePrimary: DraculaPalette.purple,
    surfaceTint: DraculaPalette.purple,
  );
}

/// Esquema Material 3 claro a partir de Alucard Classic.
ColorScheme buildAlucardColorScheme() {
  const bg = DraculaPalette.alucardBackground;

  return ColorScheme(
    brightness: Brightness.light,
    primary: DraculaPalette.alucardPurple,
    onPrimary: Colors.white,
    primaryContainer: _blend(DraculaPalette.alucardPurple, bg, 0.14),
    onPrimaryContainer: DraculaPalette.alucardForeground,
    secondary: DraculaPalette.alucardCyan,
    onSecondary: Colors.white,
    secondaryContainer: _blend(DraculaPalette.alucardCyan, bg, 0.14),
    onSecondaryContainer: DraculaPalette.alucardForeground,
    tertiary: DraculaPalette.alucardPink,
    onTertiary: Colors.white,
    tertiaryContainer: _blend(DraculaPalette.alucardPink, bg, 0.14),
    onTertiaryContainer: DraculaPalette.alucardForeground,
    error: DraculaPalette.alucardRed,
    onError: Colors.white,
    errorContainer: _blend(DraculaPalette.alucardRed, bg, 0.12),
    onErrorContainer: DraculaPalette.alucardRed,
    surface: bg,
    onSurface: DraculaPalette.alucardForeground,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: DraculaPalette.alucardFloating,
    surfaceContainer: DraculaPalette.alucardFloating,
    surfaceContainerHigh: DraculaPalette.alucardFloating,
    surfaceContainerHighest: DraculaPalette.alucardSelection,
    onSurfaceVariant: DraculaPalette.alucardComment,
    outline: DraculaPalette.alucardComment,
    outlineVariant: DraculaPalette.alucardLight,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: DraculaPalette.alucardForeground,
    onInverseSurface: DraculaPalette.alucardBackground,
    inversePrimary: DraculaPalette.alucardPurple,
    surfaceTint: DraculaPalette.alucardPurple,
  );
}

/// Colores funcionales adaptados al modo claro/oscuro (para indicadores de
/// estado que antes usaban `Colors.green/blue/amber`).
abstract final class StatusColors {
  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? DraculaPalette.green
          : DraculaPalette.alucardGreen;

  static Color info(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? DraculaPalette.cyan
          : DraculaPalette.alucardCyan;

  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? DraculaPalette.yellow
          : DraculaPalette.alucardYellow;

  static Color danger(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? DraculaPalette.red
          : DraculaPalette.alucardRed;
}
