import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/core/storage/device_storage_provider.dart';
import 'package:tether_app/features/devices/domain/device.dart';
import 'package:tether_app/features/devices/presentation/devices_screen.dart';
import 'package:tether_app/features/devices/providers/devices_provider.dart';

import '../../helpers/fake_devices.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeDevicesRepository repository;
  late FakeRealtimeService realtime;
  late DevicesController controller;

  Device device(String id, {String? name, bool online = false}) => Device(
        id: id,
        name: name ?? 'Device $id',
        platform: DevicePlatform.macos,
        isOnline: online,
        createdAt: DateTime.now(),
      );

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        devicesControllerProvider.overrideWith(
          (ref) => DevicesController(
            repository: repository,
            storage: MemoryDeviceStorage(),
            realtime: realtime,
          ),
        ),
        deviceStorageProvider.overrideWith((ref) => MemoryDeviceStorage()),
      ],
      child: const MaterialApp(home: Scaffold(body: DevicesScreen())),
    );
  }

  setUp(() {
    repository = FakeDevicesRepository();
    realtime = FakeRealtimeService();
    controller = DevicesController(
      repository: repository,
      storage: MemoryDeviceStorage(),
      realtime: realtime,
    );
  });

  tearDown(() => controller.dispose());

  testWidgets('muestra el estado vacío cuando no hay dispositivos', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Sin dispositivos'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
  });

  testWidgets('lista dispositivos con estado en línea', (tester) async {
    repository.devices.addAll([
      device('d1', name: 'MacBook', online: true),
      device('d2', name: 'iPhone'),
    ]);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('MacBook'), findsOneWidget);
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('En línea'), findsOneWidget);
    expect(find.text('Desconectado'), findsOneWidget);
  });

  testWidgets('abre el diálogo de registro y registra un dispositivo', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar dispositivo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'PC Windows');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, 1);
    expect(find.text('PC Windows'), findsOneWidget);
  });

  testWidgets('renombra un dispositivo desde el menú', (tester) async {
    repository.devices.add(device('d1', name: 'MacBook'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'MacBook Pro');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('MacBook Pro'), findsOneWidget);
    expect(find.text('MacBook'), findsNothing);
  });

  testWidgets('elimina un dispositivo confirmando el diálogo', (tester) async {
    repository.devices.add(device('d1', name: 'MacBook'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('MacBook'), findsNothing);
    expect(find.text('Sin dispositivos'), findsOneWidget);
  });
}
