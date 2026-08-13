import 'package:socket_io_client/socket_io_client.dart' as socket;

import '../config/app_config.dart';

/// Constantes de eventos del servidor (reflejan `apps/backend`).
abstract final class RealtimeEvents {
  static const deviceOnline = 'device.online';
  static const deviceOffline = 'device.offline';
  static const clipboardUpdated = 'clipboard.updated';
  static const fileReady = 'file.ready';
  static const shareCreated = 'share.created';
  static const shareAccepted = 'share.accepted';
  static const shareDownloaded = 'share.downloaded';
  static const shareExpired = 'share.expired';
  static const identify = 'device:identify';
}

enum RealtimeStatus { disconnected, connecting, connected }

/// Cliente Socket.IO conectado a `/realtime`.
///
/// La autenticación va en el handshake (`auth.token`) y, una vez conectado,
/// se identifica el dispositivo actual con `device:identify` para entrar al
/// room `device:{deviceId}` y actualizar `lastSeenAt`.
class RealtimeService {
  socket.Socket? _socket;
  String? _deviceId;

  RealtimeStatus get status =>
      _socket == null
          ? RealtimeStatus.disconnected
          : _socket!.connected
              ? RealtimeStatus.connected
              : RealtimeStatus.connecting;

  void connect(String token) {
    disconnect();

    _socket = socket.io(
      AppConfig.apiBaseUrl,
      socket.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath(AppConfig.realtimePath)
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(60)
          .build(),
    );
    _socket!.on('connect', (_) {
      final deviceId = _deviceId;
      if (deviceId != null) {
        _socket?.emit(RealtimeEvents.identify, {'deviceId': deviceId});
      }
    });
  }

  /// Marca el dispositivo actual para identificarse en cada (re)conexión.
  void identify(String deviceId) {
    _deviceId = deviceId;
    _socket?.emit(RealtimeEvents.identify, {'deviceId': deviceId});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _deviceId = null;
  }

  /// Suscribe un listener a un evento del servidor.
  /// Devuelve una función para cancelar la suscripción.
  void Function() onEvent(String event, void Function(dynamic payload) handler) {
    void listener(dynamic data) => handler(data);
    _socket?.on(event, listener);
    return () => _socket?.off(event, listener);
  }
}
