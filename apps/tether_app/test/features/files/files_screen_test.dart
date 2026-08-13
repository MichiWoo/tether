import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/features/files/domain/file_item.dart';
import 'package:tether_app/features/files/presentation/files_screen.dart';
import 'package:tether_app/features/files/providers/downloads_provider.dart';
import 'package:tether_app/features/files/providers/files_provider.dart';
import 'package:tether_app/features/files/providers/shares_provider.dart';
import 'package:tether_app/features/devices/providers/devices_provider.dart';

import '../../helpers/fake_devices.dart';
import '../../helpers/fake_files.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeFilesRepository filesRepository;
  late FakeUploadService uploadService;
  late FakeSharesRepository sharesRepository;
  late FakeRealtimeService realtime;
  late DownloadsController downloads;

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        filesControllerProvider.overrideWith(
          (ref) => FilesController(
            repository: filesRepository,
            uploadService: uploadService,
            realtime: realtime,
          )..init(),
        ),
        sharesControllerProvider.overrideWith(
          (ref) => SharesController(
            repository: sharesRepository,
            realtime: realtime,
            storage: MemoryDeviceStorage()..saveDeviceId('local'),
          )..init(),
        ),
        devicesControllerProvider.overrideWith(
          (ref) => DevicesController(
            repository: FakeDevicesRepository(),
            storage: MemoryDeviceStorage(),
            realtime: realtime,
          ),
        ),
        localDeviceIdProvider.overrideWith((ref) async => 'local'),
        downloadsControllerProvider.overrideWith((ref) => downloads),
      ],
      child: const MaterialApp(home: Scaffold(body: FilesScreen())),
    );
  }

  setUp(() {
    filesRepository = FakeFilesRepository();
    uploadService = FakeUploadService();
    sharesRepository = FakeSharesRepository();
    realtime = FakeRealtimeService();
    downloads = DownloadsController(uploadService);
  });

  testWidgets('muestra el estado vacío de archivos', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Arrastra archivos aquí'), findsOneWidget);
    expect(find.text('Sin archivos'), findsOneWidget);
  });

  testWidgets('muestra la cola de descargas con su barra de progreso',
      (tester) async {
    final gate = Completer<void>();
    uploadService.downloadGate = gate;
    downloads.start(
      name: 'informe.pdf',
      url: 'https://example.com/informe.bin',
      savePath: '/tmp/informe.pdf',
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('informe.pdf'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('lista archivos subidos con sus acciones', (tester) async {
    filesRepository.files.addAll([
      makeFileItem(id: 'f1', name: 'informe.pdf'),
      makeFileItem(id: 'f2', name: 'pendiente.zip', status: FileStatus.pending),
    ]);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('informe.pdf'), findsOneWidget);
    expect(find.text('pendiente.zip'), findsOneWidget);
    // Un archivo subido ofrece descargar/compartir; el pendiente no.
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
  });

  testWidgets('muestra un share recibido y lo acepta', (tester) async {
    sharesRepository.shares.add(
      makeShare(id: 's1', senderDeviceId: 'otro-device', fileName: 'foto.png'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compartidos'));
    await tester.pumpAndSettle();

    expect(find.text('foto.png'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.text('Aceptar'), findsNothing);
    expect(find.textContaining('Aceptado'), findsOneWidget);
    // Sigue permitiendo la descarga.
    expect(find.byIcon(Icons.download), findsOneWidget);
  });

  testWidgets('los share enviados aparecen con su estado en "Enviados"',
      (tester) async {
    sharesRepository.shares.add(
      makeShare(id: 's2', senderDeviceId: 'local', fileName: 'video.mp4'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compartidos'));
    await tester.pumpAndSettle();

    // En "Recibidos" no está, porque es mío.
    expect(find.text('video.mp4'), findsNothing);
    expect(find.text('Sin shares recibidos'), findsOneWidget);

    await tester.tap(find.text('Enviados'));
    await tester.pumpAndSettle();

    expect(find.text('video.mp4'), findsOneWidget);
    expect(find.textContaining('Pendiente'), findsOneWidget);
    // Los enviados no se descargan ni se aceptan desde aquí.
    expect(find.byIcon(Icons.download), findsNothing);
    expect(find.text('Aceptar'), findsNothing);
  });
}