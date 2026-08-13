import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_typography.dart';
import 'dracula_palette.dart';

/// Color scheme shadcn/ui a partir de Dracula Classic (oscuro).
ColorScheme _draculaScheme() => const ColorScheme(
      brightness: Brightness.dark,
      background: DraculaPalette.background,
      foreground: DraculaPalette.foreground,
      card: DraculaPalette.bgLight,
      cardForeground: DraculaPalette.foreground,
      popover: DraculaPalette.bgDark,
      popoverForeground: DraculaPalette.foreground,
      primary: DraculaPalette.purple,
      primaryForeground: DraculaPalette.bgDarker,
      secondary: DraculaPalette.cyan,
      secondaryForeground: DraculaPalette.bgDark,
      muted: DraculaPalette.selection,
      mutedForeground: DraculaPalette.comment,
      accent: DraculaPalette.pink,
      accentForeground: DraculaPalette.bgDark,
      destructive: DraculaPalette.red,
      destructiveForeground: DraculaPalette.foreground,
      border: DraculaPalette.currentLine,
      input: DraculaPalette.selection,
      ring: DraculaPalette.purple,
      chart1: DraculaPalette.green,
      chart2: DraculaPalette.cyan,
      chart3: DraculaPalette.orange,
      chart4: DraculaPalette.yellow,
      chart5: DraculaPalette.pink,
    );

/// Color scheme shadcn/ui a partir de Alucard Classic (claro).
ColorScheme _alucardScheme() => const ColorScheme(
      brightness: Brightness.light,
      background: DraculaPalette.alucardBackground,
      foreground: DraculaPalette.alucardForeground,
      card: Colors.white,
      cardForeground: DraculaPalette.alucardForeground,
      popover: DraculaPalette.alucardFloating,
      popoverForeground: DraculaPalette.alucardForeground,
      primary: DraculaPalette.alucardPurple,
      primaryForeground: Colors.white,
      secondary: DraculaPalette.alucardCyan,
      secondaryForeground: Colors.white,
      muted: DraculaPalette.alucardLight,
      mutedForeground: DraculaPalette.alucardComment,
      accent: DraculaPalette.alucardPink,
      accentForeground: Colors.white,
      destructive: DraculaPalette.alucardRed,
      destructiveForeground: Colors.white,
      border: DraculaPalette.alucardLight,
      input: DraculaPalette.alucardSelection,
      ring: DraculaPalette.alucardPurple,
      chart1: DraculaPalette.alucardGreen,
      chart2: DraculaPalette.alucardCyan,
      chart3: Color(0xFFA34D14),
      chart4: Color(0xFF846E15),
      chart5: DraculaPalette.alucardPink,
    );

/// Construye el `ThemeData` de shadcn_flutter con la paleta de Tether.
ThemeData buildShadcnTheme(Brightness brightness) => ThemeData(
      colorScheme:
          brightness == Brightness.dark ? _draculaScheme() : _alucardScheme(),
      radius: 0.5,
      scaling: 1,
      typography: const Typography.geist(
        sans: TextStyle(fontFamily: AppFonts.body),
        mono: TextStyle(fontFamily: AppFonts.mono),
        inlineCode: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

/// Provee el tema de shadcn_flutter a sus descendientes.
///
/// Se envuelve sobre el `MaterialApp` (en su `builder`) para que los
/// componentes de shadcn tengan un ancestro `Theme` sin chocar con Material.
class TetherShadcnTheme extends StatelessWidget {
  const TetherShadcnTheme({
    super.key,
    required this.brightness,
    required this.child,
  });

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: buildShadcnTheme(brightness), child: child);
  }
}
