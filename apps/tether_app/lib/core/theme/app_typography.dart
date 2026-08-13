import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad tipográfica de Tether.
///
/// Sora para display y cuerpo; JetBrains Mono para datos, IDs, fechas,
/// tamaños y etiquetas de estado (refuerza el carácter "señal/terminal").
abstract final class AppFonts {
  static const String display = 'Sora';
  static const String body = 'Sora';
  static const String mono = 'JetBrainsMono';

  static TextStyle monoStyle({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
