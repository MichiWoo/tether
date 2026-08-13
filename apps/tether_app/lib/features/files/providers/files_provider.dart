import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/realtime_service.dart';
import '../data/files_api.dart';
import '../data/files_repository.dart';
import '../data/upload_service.dart';
import '../domain/file_item.dart';

/// Tamaño máximo real permitido por el backend (Prisma `Int` 32-bit).
const maxFileSizeBytes = 2147483647; // ~2 GB

final filesApiProvider = Provider<FilesApi>(
  (ref) => FilesApi(ref.watch(apiClientProvider)),
);

final filesRepositoryProvider = Provider<FilesRepository>(
  (ref) => FilesRepository(ref.watch(filesApiProvider)),
);

final uploadServiceProvider = Provider<UploadService>(
  (ref) => UploadService(),
);

/// Estado de una subida individual.
class UploadTask {
  const UploadTask({
    required this.id,
    required this.name,
    required this.progress,
    this.error,
  });

  final String id;
  final String name;
  final double progress;
  final String? error;

  UploadTask copyWith({double? progress, String? error}) => UploadTask(
        id: id,
        name: name,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}

class FilesState {
  const FilesState({
    required this.files,
    required this.uploads,
    this.isLoading = false,
    this.error,
  });

  final List<FileItem> files;
  final List<UploadTask> uploads;
  final bool isLoading;
  final String? error;

  FilesState copyWith({
    List<FileItem>? files,
    List<UploadTask>? uploads,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => FilesState(
        files: files ?? this.files,
        uploads: uploads ?? this.uploads,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final filesControllerProvider =
    StateNotifierProvider<FilesController, FilesState>(
      (ref) => FilesController(
        repository: ref.watch(filesRepositoryProvider),
        uploadService: ref.watch(uploadServiceProvider),
        realtime: ref.watch(realtimeServiceProvider),
      )..init(),
    );

class FilesController extends StateNotifier<FilesState> {
  FilesController({
    required this.repository,
    required this.uploadService,
    required this.realtime,
  }) : super(const FilesState(files: [], uploads: [])) {
    _cancelFileReady = realtime.onEvent(
      RealtimeEvents.fileReady,
      _onFileReady,
    );
  }

  final FilesRepository repository;
  final UploadService uploadService;
  final RealtimeService realtime;
  late final void Function() _cancelFileReady;

  @override
  void dispose() {
    _cancelFileReady();
    super.dispose();
  }

  Future<void> init() => load();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final files = await repository.list();
      state = FilesState(files: files, uploads: state.uploads);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron cargar los archivos.',
      );
    }
  }

  /// Sube varios archivos por ruta local (drag & drop o picker).
  Future<void> uploadPaths(List<String> paths) async {
    for (final path in paths) {
      await _uploadOne(path);
    }
  }

  Future<void> _uploadOne(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    final name = p.basename(path);
    final size = await file.length();

    if (size > maxFileSizeBytes) {
      _addUploadTask(
        UploadTask(
          id: path,
          name: name,
          progress: 0,
          error: 'Máximo permitido: 2 GB',
        ),
      );
      return;
    }

    final mimeType = lookupMimeType(path) ?? 'application/octet-stream';
    final taskId = path;
    _addUploadTask(UploadTask(id: taskId, name: name, progress: 0));

    try {
      final created = await repository.create(
        name: name,
        size: size,
        mimeType: mimeType,
      );

      await uploadService.upload(
        url: created.uploadUrl,
        path: path,
        contentType: created.uploadContentType,
        onProgress: (progress) {
          _updateUpload(taskId, (t) => t.copyWith(progress: progress));
        },
      );

      final completed = await repository.complete(created.file.id);
      _upsertFile(completed);
      dismissUpload(taskId);
    } on DioException catch (_) {
      _updateUpload(
        taskId,
        (t) => t.copyWith(error: 'Error de red al subir.'),
      );
    } catch (_) {
      _updateUpload(
        taskId,
        (t) => t.copyWith(error: 'No se pudo subir el archivo.'),
      );
    }
  }

  /// Devuelve la URL firmada de descarga del archivo.
  Future<String> getDownloadUrl(String id) => repository.getDownloadUrl(id);

  Future<void> delete(String id) async {
    await repository.delete(id);
    state = state.copyWith(
      files: state.files.where((f) => f.id != id).toList(),
    );
  }

  void _onFileReady(dynamic payload) {
    final raw = payload is Map ? payload : const <String, dynamic>{};
    final fileRaw = raw['file'];
    if (fileRaw is! Map) return;
    final file = FileItem.fromJson(Map<String, dynamic>.from(fileRaw));
    _upsertFile(file);
  }

  void _upsertFile(FileItem file) {
    final exists = state.files.any((f) => f.id == file.id);
    state = state.copyWith(
      files: exists
          ? [
              for (final f in state.files)
                if (f.id == file.id) file else f,
            ]
          : [file, ...state.files],
    );
  }

  void _addUploadTask(UploadTask task) {
    final index = state.uploads.indexWhere((t) => t.id == task.id);
    final uploads = index >= 0
        ? [
            for (final t in state.uploads)
              if (t.id == task.id) task else t,
          ]
        : [...state.uploads, task];
    state = state.copyWith(uploads: uploads);
  }

  void _updateUpload(String id, UploadTask Function(UploadTask) update) {
    state = state.copyWith(
      uploads: [
        for (final t in state.uploads)
          if (t.id == id) update(t) else t,
      ],
    );
  }

  /// Quita una subida de la lista (completada, fallida o descartada).
  void dismissUpload(String id) {
    state = state.copyWith(
      uploads: state.uploads.where((t) => t.id != id).toList(),
    );
  }
}
