import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/features/clipboard/domain/clipboard_item.dart';
import 'package:tether_app/features/clipboard/presentation/clipboard_screen.dart';
import 'package:tether_app/features/clipboard/providers/clipboard_provider.dart';
import 'package:tether_app/features/devices/providers/devices_provider.dart';

import '../../helpers/fake_clipboard.dart';
import '../../helpers/fake_devices.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeClipboardRepository repository;
  late FakeRealtimeService realtime;
  late ClipboardController controller;

  ClipboardItem item(String id, String content, {String? source}) => ClipboardItem(
        id: id,
        content: content,
        sourceDeviceName: source,
        createdAt: DateTime.now(),
      );

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        clipboardControllerProvider.overrideWith(
          (ref) => ClipboardController(
            repository: repository,
            realtime: realtime,
          ),
        ),
        devicesControllerProvider.overrideWith(
          (ref) => DevicesController(
            repository: FakeDevicesRepository(),
            storage: MemoryDeviceStorage(),
            realtime: realtime,
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: ClipboardScreen())),
    );
  }

  setUp(() {
    repository = FakeClipboardRepository();
    realtime = FakeRealtimeService();
    controller = ClipboardController(repository: repository, realtime: realtime);
  });

  tearDown(() => controller.dispose());

  testWidgets('muestra el estado vacío sin historial', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Sin historial'), findsOneWidget);
  });

  testWidgets('muestra el historial', (tester) async {
    repository.items.addAll([
      item('c1', 'hola desde iPhone', source: 'iPhone'),
      item('c2', 'otro texto', source: 'MacBook'),
    ]);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('hola desde iPhone'), findsOneWidget);
    expect(find.text('otro texto'), findsOneWidget);
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('MacBook'), findsOneWidget);
  });

  testWidgets('envía texto desde el campo de entrada', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'texto nuevo');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repository.pushCalls, 1);
    expect(find.text('texto nuevo'), findsOneWidget);
  });
}
