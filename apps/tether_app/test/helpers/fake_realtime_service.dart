import 'package:tether_app/core/realtime/realtime_service.dart';

/// RealtimeService sin conexión real para tests: registra los listeners y
/// permite emitir eventos manualmente.
class FakeRealtimeService extends RealtimeService {
  final Map<String, List<void Function(dynamic)>> _listeners = {};
  final List<String> identifiedDevices = [];

  @override
  void connect(String token) {}

  @override
  void disconnect() {
    identifiedDevices.clear();
  }

  @override
  void identify(String deviceId) {
    identifiedDevices.add(deviceId);
  }

  @override
  void Function() onEvent(String event, void Function(dynamic payload) handler) {
    _listeners.putIfAbsent(event, () => []).add(handler);
    return () => _listeners[event]?.remove(handler);
  }

  void emit(String event, dynamic payload) {
    for (final handler in _listeners[event] ?? const []) {
      handler(payload);
    }
  }
}
