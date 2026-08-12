import 'package:socket_io_client/socket_io_client.dart' as socket;

import '../config/app_config.dart';

enum RealtimeStatus { disconnected, connecting, connected }

/// Cliente Socket.IO conectado a `/realtime`.
///
/// La autenticación va en el handshake (`auth.token`). En esta iteración
/// expone el estado de conexión; los eventos por feature se consumen
/// a partir de la iteración 2.
class RealtimeService {
  socket.Socket? _socket;

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
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  /// Suscribe un listener a un evento del servidor.
  void onEvent(String event, void Function(dynamic payload) handler) {
    _socket?.on(event, (data) => handler(data));
  }
}
