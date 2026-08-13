import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/features/devices/domain/device.dart';
import 'package:tether_app/features/devices/providers/devices_provider.dart';
import 'package:tether_app/core/realtime/realtime_service.dart';

import '../../helpers/fake_devices.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeDevicesRepository repository;
  late MemoryDeviceStorage storage;
  late FakeRealtimeService realtime;
  late DevicesController controller;

  setUp(() {
    repository = FakeDevicesRepository();
    storage = MemoryDeviceStorage();
    realtime = FakeRealtimeService();
    controller = DevicesController(
      repository: repository,
      storage: storage,
      realtime: realtime,
    );
  });

  tearDown(() => controller.dispose());

  Device device(String id, {bool online = false}) => Device(
        id: id,
        name: 'Device $id',
        platform: DevicePlatform.macos,
        isOnline: online,
        createdAt: DateTime.now(),
      );

  group('load', () {
    test('carga la lista de dispositivos', () async {
      repository.devices.addAll([device('d1'), device('d2', online: true)]);
      await controller.load();
      expect(controller.state.devices.length, 2);
      expect(controller.state.error, isNull);
    });

    test('expone error si falla la carga', () async {
      repository.failLoad = true;
      await controller.load();
      expect(controller.state.devices, isEmpty);
      expect(controller.state.error, isNotNull);
    });
  });

  group('ensureCurrentDevice', () {
    test('registra, guarda e identifica el equipo la primera vez', () async {
      final id = await controller.ensureCurrentDevice(
        name: 'macOS',
        platform: DevicePlatform.macos,
      );
      expect(id, isNotEmpty);
      expect(await storage.readDeviceId(), id);
      expect(realtime.identifiedDevices, contains(id));
      expect(controller.state.devices.length, 1);
    });

    test('si ya existe, solo identifica sin re-registrar', () async {
      await storage.saveDeviceId('d1');
      repository.devices.add(device('d1'));

      final id = await controller.ensureCurrentDevice(
        name: 'macOS',
        platform: DevicePlatform.macos,
      );
      expect(id, 'd1');
      expect(realtime.identifiedDevices, contains('d1'));
      expect(repository.registerCalls, 0);
    });
  });

  group('register/rename/delete', () {
    test('registra y agrega al inicio', () async {
      await controller.register(
        name: 'iPhone',
        platform: DevicePlatform.ios,
      );
      expect(controller.state.devices.first.name, 'iPhone');
      expect(repository.registerCalls, 1);
    });

    test('renombra y actualiza la lista', () async {
      repository.devices.add(device('d1'));
      await controller.load();
      await controller.rename('d1', 'Nuevo nombre');
      expect(controller.state.devices.single.name, 'Nuevo nombre');
    });

    test('elimina de la lista', () async {
      repository.devices.addAll([device('d1'), device('d2')]);
      await controller.load();
      await controller.delete('d1');
      expect(controller.state.devices.single.id, 'd2');
      expect(repository.deleteCalls, 1);
    });
  });

  group('eventos en vivo', () {
    test('device.online marca online el dispositivo', () async {
      repository.devices.add(device('d1'));
      await controller.load();
      expect(controller.state.devices.single.isOnline, isFalse);

      realtime.emit(RealtimeEvents.deviceOnline, {'deviceId': 'd1'});
      expect(controller.state.devices.single.isOnline, isTrue);
    });

    test('device.offline marca offline', () async {
      repository.devices.add(device('d1', online: true));
      await controller.load();

      realtime.emit(RealtimeEvents.deviceOffline, {'deviceId': 'd1'});
      expect(controller.state.devices.single.isOnline, isFalse);
    });

    test('ignora eventos de dispositivos desconocidos', () async {
      repository.devices.add(device('d1'));
      await controller.load();
      realtime.emit(RealtimeEvents.deviceOnline, {'deviceId': 'nope'});
      expect(controller.state.devices.single.isOnline, isFalse);
    });
  });
}
