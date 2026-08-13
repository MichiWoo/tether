import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:tether_app/core/tray/tray_service.dart';

void main() {
  group('buildTrayMenu', () {
    test('tiene mostrar, autostart y salir', () {
      final menu = buildTrayMenu(autostartEnabled: true);
      final items = menu.items!;

      expect(items.length, 4);
      expect(items[0].key, 'show');
      expect(items[0].label, 'Mostrar Tether');
      expect(items[1].key, 'autostart');
      expect(items[1].type, 'checkbox');
      expect(items[2].type, 'separator');
      expect(items[3].key, 'quit');
      expect(items[3].label, 'Salir');
    });

    test('refleja el estado de autostart en el checkbox', () {
      final enabled = buildTrayMenu(autostartEnabled: true);
      final checkboxEnabled =
          enabled.items!.firstWhere((i) => i.key == 'autostart');
      expect(checkboxEnabled.checked, isTrue);

      final disabled = buildTrayMenu(autostartEnabled: false);
      final checkboxDisabled =
          disabled.items!.firstWhere((i) => i.key == 'autostart');
      expect(checkboxDisabled.checked, isFalse);
    });

    test('conecta los callbacks de cada item', () {
      MenuItem? clicked;
      buildTrayMenu(
        autostartEnabled: false,
        onQuit: (item) => clicked = item,
      ).items!.firstWhere((i) => i.key == 'quit').onClick?.call(
            MenuItem(key: 'quit'),
          );

      expect(clicked?.key, 'quit');
    });
  });
}
