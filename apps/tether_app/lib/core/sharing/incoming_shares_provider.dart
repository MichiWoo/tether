import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/clipboard/providers/clipboard_provider.dart';
import '../../features/files/providers/files_provider.dart';
import '../navigation/home_section.dart';
import '../storage/device_storage.dart';
import '../storage/device_storage_provider.dart';
import 'receive_sharing_service.dart';

final receiveSharingServiceProvider = Provider<ReceiveSharingService>(
  (ref) => ReceiveSharingService(),
);

/// Estado del procesamiento de shares entrantes (solo para indicar actividad).
class IncomingSharesState {
  const IncomingSharesState({this.isProcessing = false});

  final bool isProcessing;

  IncomingSharesState copyWith({bool? isProcessing}) => IncomingSharesState(
        isProcessing: isProcessing ?? this.isProcessing,
      );
}

final incomingSharesControllerProvider =
    StateNotifierProvider<IncomingSharesController, IncomingSharesState>((ref) {
  return IncomingSharesController(
    service: ref.watch(receiveSharingServiceProvider),
    files: ref.read(filesControllerProvider.notifier),
    clipboard: ref.read(clipboardControllerProvider.notifier),
    storage: ref.watch(deviceStorageProvider),
    onFilesReceived: () {
      ref.read(homeSectionProvider.notifier).state = HomeSection.files;
    },
  );
});

/// Procesa contenido compartido hacia Tether desde otras apps.
///
/// El texto y las URLs se envían al portapapeles (sync a otros dispositivos);
/// los archivos/imágenes/videos se suben a "Mis archivos". La suscripción se
/// activa solo con sesión iniciada (la orquesta `app.dart`).
class IncomingSharesController extends StateNotifier<IncomingSharesState> {
  IncomingSharesController({
    required this.service,
    required this.files,
    required this.clipboard,
    required this.storage,
    this.onFilesReceived,
  }) : super(const IncomingSharesState());

  final ReceiveSharingService service;
  final FilesController files;
  final ClipboardController clipboard;
  final DeviceStorage storage;

  /// Se invoca al recibir archivos (para navegar a la pestaña de Archivos).
  final void Function()? onFilesReceived;

  StreamSubscription<List<SharedMediaFile>>? _sub;

  /// Empieza a escuchar shares entrantes y consume el intent inicial.
  /// Devuelve un `Future` que se completa al terminar el intent inicial.
  Future<void> start() {
    _sub ??= service.mediaStream.listen(process);
    return _consumeInitial();
  }

  /// Detiene la escucha (al cerrar sesión).
  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> _consumeInitial() async {
    final media = await service.getInitialMedia();
    if (media.isNotEmpty) {
      await process(media);
    }
    await service.reset();
  }

  /// Procesa contenido compartido entrante: texto/URL al portapapeles,
  /// archivos/imágenes/videos a "Mis archivos".
  Future<void> process(List<SharedMediaFile> media) async {
    if (media.isEmpty) return;
    state = state.copyWith(isProcessing: true);
    try {
      final filePaths = <String>[];
      final sourceDeviceId = await storage.readDeviceId();
      for (final item in media) {
        if (item.type == SharedMediaType.text ||
            item.type == SharedMediaType.url) {
          await clipboard.push(
            content: item.path,
            sourceDeviceId: sourceDeviceId,
          );
        } else {
          filePaths.add(item.path);
        }
      }
      if (filePaths.isNotEmpty) {
        onFilesReceived?.call();
        await files.uploadPaths(filePaths);
      }
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }
}
