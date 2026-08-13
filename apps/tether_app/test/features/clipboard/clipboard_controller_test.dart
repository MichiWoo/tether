import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/core/realtime/realtime_service.dart';
import 'package:tether_app/features/clipboard/domain/clipboard_item.dart';
import 'package:tether_app/features/clipboard/providers/clipboard_provider.dart';

import '../../helpers/fake_clipboard.dart';
import '../../helpers/fake_devices.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeClipboardRepository repository;
  late FakeRealtimeService realtime;
  late FakeClipboardWriter writer;
  late MemoryDeviceStorage storage;
  late ClipboardController controller;

  setUp(() {
    repository = FakeClipboardRepository();
    realtime = FakeRealtimeService();
    writer = FakeClipboardWriter();
    storage = MemoryDeviceStorage()..saveDeviceId('local-device');
    controller = ClipboardController(
      repository: repository,
      realtime: realtime,
      storage: storage,
      clipboard: writer,
    );
  });

  tearDown(() => controller.dispose());

  ClipboardItem item(String id, String content) => ClipboardItem(
        id: id,
        content: content,
        sourceDeviceName: 'iPhone',
        createdAt: DateTime.now(),
      );

  group('loadHistory', () {
    test('carga el historial', () async {
      repository.items.addAll([item('c1', 'hola'), item('c2', 'mundo')]);
      await controller.loadHistory();
      expect(controller.state.items.length, 2);
      expect(controller.state.error, isNull);
    });

    test('expone error si falla', () async {
      repository.failHistory = true;
      await controller.loadHistory();
      expect(controller.state.items, isEmpty);
      expect(controller.state.error, isNotNull);
    });
  });

  group('push', () {
    test('inserta el item nuevo al inicio', () async {
      await controller.push(content: 'nuevo texto', sourceDeviceId: 'd1');
      expect(controller.state.items.first.content, 'nuevo texto');
      expect(repository.pushCalls, 1);
    });

    test('no duplica si el servidor dedupe devuelve item existente', () async {
      repository.items.add(item('c1', 'hola'));
      await controller.loadHistory();
      await controller.push(content: 'hola', sourceDeviceId: 'd1');
      expect(controller.state.items.length, 1);
    });

    test('expone error si falla', () async {
      repository.failPush = true;
      await controller.push(content: 'x');
      expect(controller.state.error, isNotNull);
    });
  });

  group('clipboard.updated en vivo', () {
    test('inserta el item recibido al inicio', () {
      realtime.emit(RealtimeEvents.clipboardUpdated, {
        'item': {
          'id': 'c9',
          'content': 'en vivo',
          'sourceDeviceId': 'd2',
          'sourceDeviceName': 'Android',
          'createdAt': DateTime.now().toIso8601String(),
        },
        'sourceDeviceId': 'd2',
      });
      expect(controller.state.items.single.content, 'en vivo');
    });

    test('auto-copia el contenido si viene de otro dispositivo', () async {
      realtime.emit(RealtimeEvents.clipboardUpdated, {
        'item': {
          'id': 'c10',
          'content': 'hola remoto',
          'sourceDeviceId': 'd2',
          'sourceDeviceName': 'Android',
          'createdAt': DateTime.now().toIso8601String(),
        },
        'sourceDeviceId': 'd2',
      });
      await Future<void>.delayed(Duration.zero);

      expect(writer.written, contains('hola remoto'));
      expect(controller.state.autoCopiedItem?.id, 'c10');
    });

    test('no auto-copia si el item es del propio dispositivo', () async {
      realtime.emit(RealtimeEvents.clipboardUpdated, {
        'item': {
          'id': 'c11',
          'content': 'eco propio',
          'sourceDeviceId': 'local-device',
          'sourceDeviceName': 'Este equipo',
          'createdAt': DateTime.now().toIso8601String(),
        },
        'sourceDeviceId': 'local-device',
      });
      await Future<void>.delayed(Duration.zero);

      expect(writer.written, isEmpty);
      expect(controller.state.autoCopiedItem, isNull);
    });

    test('clearAutoCopied limpia el aviso', () async {
      realtime.emit(RealtimeEvents.clipboardUpdated, {
        'item': {
          'id': 'c12',
          'content': 'otro',
          'sourceDeviceId': 'd2',
          'sourceDeviceName': 'Android',
          'createdAt': DateTime.now().toIso8601String(),
        },
        'sourceDeviceId': 'd2',
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.autoCopiedItem, isNotNull);

      controller.clearAutoCopied();
      expect(controller.state.autoCopiedItem, isNull);
    });
  });
}
