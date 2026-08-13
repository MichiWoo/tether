import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/upload_service.dart';
import 'files_provider.dart';

/// Estado de una descarga individual.
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.name,
    required this.progress,
    this.error,
  });

  final String id;
  final String name;
  final double progress;
  final String? error;

  bool get isDone => progress >= 1.0;

  DownloadTask copyWith({double? progress, String? error}) => DownloadTask(
        id: id,
        name: name,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}

class DownloadsState {
  const DownloadsState({required this.downloads});

  final List<DownloadTask> downloads;

  DownloadsState copyWith({List<DownloadTask>? downloads}) => DownloadsState(
        downloads: downloads ?? this.downloads,
      );
}

final downloadsControllerProvider =
    StateNotifierProvider<DownloadsController, DownloadsState>(
      (ref) => DownloadsController(ref.watch(uploadServiceProvider)),
    );

/// Cola de descargas con progreso por archivo y cancelación.
///
/// Cada `start` corre en paralelo; el tile se actualiza vía `onProgress` y se
/// quita al terminar (éxito o cancelación). Los errores se mantienen visibles
/// hasta que el usuario los descarta con `dismiss`.
class DownloadsController extends StateNotifier<DownloadsState> {
  DownloadsController(this.uploadService)
      : super(const DownloadsState(downloads: []));

  final UploadService uploadService;
  final Map<String, CancelToken> _tokens = {};
  int _seq = 0;

  @override
  void dispose() {
    for (final token in _tokens.values) {
      token.cancel();
    }
    super.dispose();
  }

  /// Inicia la descarga de [name] hacia [savePath]. Devuelve `true` si terminó
  /// correctamente, `false` si falló o fue cancelada.
  Future<bool> start({
    required String name,
    required String url,
    required String savePath,
  }) async {
    final id = '${name}_${_seq++}';
    final token = CancelToken();
    _tokens[id] = token;
    _upsert(DownloadTask(id: id, name: name, progress: 0));

    try {
      await uploadService.download(
        url: url,
        savePath: savePath,
        cancelToken: token,
        onProgress: (progress) {
          _update(id, (t) => t.copyWith(progress: progress));
        },
      );
      _tokens.remove(id);
      _remove(id);
      return true;
    } on DioException catch (e) {
      _tokens.remove(id);
      if (CancelToken.isCancel(e)) {
        _remove(id);
      } else {
        _update(id, (t) => t.copyWith(error: 'Error de red al descargar.'));
      }
      return false;
    } catch (_) {
      _tokens.remove(id);
      _update(id, (t) => t.copyWith(error: 'No se pudo descargar el archivo.'));
      return false;
    }
  }

  /// Cancela una descarga en curso.
  void cancel(String id) {
    _tokens.remove(id)?.cancel();
    _remove(id);
  }

  /// Quita un tile (error o completado) de la cola.
  void dismiss(String id) => _remove(id);

  void _upsert(DownloadTask task) {
    final index = state.downloads.indexWhere((t) => t.id == task.id);
    state = state.copyWith(
      downloads: index >= 0
          ? [
              for (final t in state.downloads)
                if (t.id == task.id) task else t,
            ]
          : [...state.downloads, task],
    );
  }

  void _update(String id, DownloadTask Function(DownloadTask) update) {
    state = state.copyWith(
      downloads: [
        for (final t in state.downloads)
          if (t.id == id) update(t) else t,
      ],
    );
  }

  void _remove(String id) {
    state = state.copyWith(
      downloads: state.downloads.where((t) => t.id != id).toList(),
    );
  }
}
