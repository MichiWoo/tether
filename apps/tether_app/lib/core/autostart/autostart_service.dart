import 'package:flutter/services.dart';

/// Abstracción del arranque al iniciar sesión (autostart).
///
/// Habla con el código nativo de macOS vía el canal `tether/autostart`, que
/// registra un LaunchAgent en `~/Library/LaunchAgents`. No usa paquetes
/// externos para evitar la dependencia de Swift Package Manager.
class AutostartService {
  AutostartService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('tether/autostart');

  final MethodChannel _channel;

  Future<bool> isEnabled() async =>
      await _channel.invokeMethod<bool>('isEnabled') ?? false;

  Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod('setEnabled', {'enabled': enabled});
  }
}
