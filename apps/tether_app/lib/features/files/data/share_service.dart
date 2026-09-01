import 'package:share_plus/share_plus.dart';

/// Comparte contenido con otras apps vía el share sheet del sistema
/// (ACTION_SEND en Android / UIActivityViewController en iOS).
///
/// Se mantiene como clase concreta con método sobrescribible para poder
/// falsearla en tests (mismo patrón que `ClipboardWriter`).
class ShareService {
  /// Abre el share sheet para el archivo local en [path], opcionalmente con
  /// un [text] de acompañamiento.
  Future<void> shareFile({required String path, String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: text),
    );
  }

  /// Abre el share sheet solo con texto.
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
