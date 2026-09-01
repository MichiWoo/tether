import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secciones de la pantalla principal (orden de la barra de navegación).
enum HomeSection { devices, clipboard, files }

/// Sección activa del shell. Permite saltar de sección desde fuera
/// (por ejemplo, al recibir archivos compartidos desde otra app).
final homeSectionProvider = StateProvider<HomeSection>(
  (ref) => HomeSection.clipboard,
);
