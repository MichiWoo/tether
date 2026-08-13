import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../autostart/autostart_service.dart';

/// Construye el menú contextual del icono de bandeja.
///
/// Función pura para poder testear su estructura sin tocar los canales
/// nativos.
Menu buildTrayMenu({
  required bool autostartEnabled,
  void Function(MenuItem)? onShow,
  void Function(MenuItem)? onAutostart,
  void Function(MenuItem)? onQuit,
}) {
  return Menu(
    items: [
      MenuItem(key: 'show', label: 'Mostrar Tether', onClick: onShow),
      MenuItem.checkbox(
        key: 'autostart',
        label: 'Abrir al iniciar sesión',
        checked: autostartEnabled,
        onClick: onAutostart,
      ),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Salir', onClick: onQuit),
    ],
  );
}

/// Icono de bandeja del sistema + minimizar a bandeja + autostart.
///
/// Solo para desktop (macOS/windows/linux). Se inicializa una vez en
/// `main.dart` cuando la plataforma es de escritorio.
class TrayService with WindowListener, TrayListener {
  TrayService({AutostartService? autostart})
      : _autostart = autostart ?? AutostartService();

  final AutostartService _autostart;
  bool _initialized = false;
  bool _quitting = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await trayManager.setIcon(
      'assets/tray_icon.png',
      isTemplate: true,
    );
    await trayManager.setToolTip('Tether');
    await _refreshMenu();

    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  /// Reconstruye el menú con el estado actual de autostart.
  Future<void> _refreshMenu() async {
    final autostartEnabled = await _autostart.isEnabled();
    await trayManager.setContextMenu(
      buildTrayMenu(
        autostartEnabled: autostartEnabled,
        onShow: (_) => showWindow(),
        onAutostart: _onToggleAutostart,
        onQuit: (_) => quit(),
      ),
    );
  }

  Future<void> _onToggleAutostart(MenuItem item) async {
    final enabled = !(item.checked ?? false);
    item.checked = enabled;
    await _autostart.setEnabled(enabled);
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    _quitting = true;
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => showWindow();

  @override
  void onWindowClose() {
    if (!_quitting) {
      windowManager.hide();
    }
  }
}
