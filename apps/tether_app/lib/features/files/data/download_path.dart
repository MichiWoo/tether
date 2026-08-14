import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/platform/platform_info.dart';

/// Ruta donde se descarga el archivo antes de persistirlo.
///
/// En Android se descarga a un archivo temporal y después se abre el diálogo
/// "guardar como" (SAF), porque no hay escritura directa a carpetas públicas.
/// En desktop/iOS la ruta ya es la definitiva (`getSaveLocation`).
Future<String?> resolveDownloadPath(String name) async {
  if (isAndroid) {
    final dir = await getTemporaryDirectory();
    return p.join(dir.path, name);
  }
  final location = await getSaveLocation(suggestedName: name);
  return location?.path;
}

/// Persiste la descarga temporal en Android vía el diálogo "guardar como".
///
/// Devuelve la ruta final elegida por el usuario, o `null` si canceló. En
/// desktop/iOS la ruta ya es la definitiva y se devuelve tal cual. El archivo
/// temporal se elimina al terminar (éxito o cancelación).
Future<String?> persistDownload(String tempPath, String name) async {
  if (!isAndroid) return tempPath;

  final String? saved;
  try {
    saved = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(sourceFilePath: tempPath, fileName: name),
    );
  } catch (_) {
    // Si el diálogo falla, se conserva el temporal como último recurso.
    return tempPath;
  }

  final tmp = File(tempPath);
  if (await tmp.exists()) {
    try {
      await tmp.delete();
    } catch (_) {}
  }
  return saved;
}
