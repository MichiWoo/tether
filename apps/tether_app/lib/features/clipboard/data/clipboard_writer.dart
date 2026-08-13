import 'package:super_clipboard/super_clipboard.dart';

/// Abstracción del portapapeles del sistema (`super_clipboard`) para poder
/// inyectarla/fake-arla en tests y reutilizarla desde el controller y la UI.
class ClipboardWriter {
  /// Copia [text] al portapapeles. Devuelve `false` si no está disponible
  /// (o falla), sin lanzar excepciones.
  Future<bool> writeText(String text) async {
    try {
      final systemClipboard = SystemClipboard.instance;
      if (systemClipboard == null) return false;
      final itemWriter = DataWriterItem();
      itemWriter.add(Formats.plainText(text));
      await systemClipboard.write([itemWriter]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
