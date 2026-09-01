import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Wrapper inyectable de `receive_sharing_intent` para aislar la capa de
/// plataforma y poder falsearla en tests.
///
/// En la versión actual del plugin no hay stream de texto separado: el texto
/// y las URLs llegan como [SharedMediaFile] con `type == SharedMediaType.text`
/// o `SharedMediaType.url` (y el contenido en `path`).
class ReceiveSharingService {
  ReceiveSharingService({ReceiveSharingIntent? intent})
      : _intent = intent ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _intent;

  /// Media compartida mientras la app está en memoria (warm start).
  Stream<List<SharedMediaFile>> get mediaStream => _intent.getMediaStream();

  /// Media que lanzó la app (cold start). Consumir y luego llamar [reset].
  Future<List<SharedMediaFile>> getInitialMedia() => _intent.getInitialMedia();

  /// Limpia el intent inicial tras procesarlo para no reprocesarlo.
  Future<void> reset() => _intent.reset();
}
