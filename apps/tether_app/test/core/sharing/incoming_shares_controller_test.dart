import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:tether_app/core/sharing/incoming_shares_provider.dart';
import 'package:tether_app/features/clipboard/providers/clipboard_provider.dart';
import 'package:tether_app/features/files/providers/files_provider.dart';

import '../../helpers/fake_clipboard.dart';
import '../../helpers/fake_devices.dart';
import '../../helpers/fake_files.dart';
import '../../helpers/fake_receive_sharing_service.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeReceiveSharingService service;
  late FakeFilesRepository filesRepository;
  late FakeUploadService uploadService;
  late FakeRealtimeService realtime;
  late FilesController filesController;
  late FakeClipboardRepository clipboardRepository;
  late FakeClipboardWriter writer;
  late MemoryDeviceStorage storage;
  late ClipboardController clipboardController;
  late IncomingSharesController controller;

  int filesReceivedCalls = 0;

  setUp(() {
    service = FakeReceiveSharingService();
    filesRepository = FakeFilesRepository();
    uploadService = FakeUploadService();
    realtime = FakeRealtimeService();
    filesController = FilesController(
      repository: filesRepository,
      uploadService: uploadService,
      realtime: realtime,
    );
    clipboardRepository = FakeClipboardRepository();
    writer = FakeClipboardWriter();
    storage = MemoryDeviceStorage()..saveDeviceId('local-device');
    clipboardController = ClipboardController(
      repository: clipboardRepository,
      realtime: realtime,
      storage: storage,
      clipboard: writer,
    );
    filesReceivedCalls = 0;
    controller = IncomingSharesController(
      service: service,
      files: filesController,
      clipboard: clipboardController,
      storage: storage,
      onFilesReceived: () => filesReceivedCalls++,
    );
  });

  tearDown(() {
    controller.dispose();
    filesController.dispose();
    clipboardController.dispose();
  });

  group('intent inicial (cold start)', () {
    test('sube archivos y avisa onFilesReceived', () async {
      final dir = await Directory.systemTemp.createTemp('tether_share');
      final file = File('${dir.path}/foto.jpg');
      await file.writeAsBytes([1, 2, 3]);

      service.initialMedia = [makeSharedMedia(path: file.path)];
      await controller.start();

      expect(uploadService.uploadedPaths, contains(file.path));
      expect(filesReceivedCalls, 1);
      expect(service.resetCalls, 1);
      await dir.delete(recursive: true);
    });

    test('envía texto al portapapeles', () async {
      service.initialMedia = [
        makeSharedMedia(path: 'hola desde otra app', type: SharedMediaType.text),
      ];
      await controller.start();

      expect(clipboardRepository.pushCalls, 1);
      expect(clipboardRepository.items.first.content, 'hola desde otra app');
      expect(clipboardRepository.items.first.sourceDeviceId, 'local-device');
      expect(service.resetCalls, 1);
    });

    test('envía URLs al portapapeles como texto', () async {
      service.initialMedia = [
        makeSharedMedia(path: 'https://example.com', type: SharedMediaType.url),
      ];
      await controller.start();

      expect(clipboardRepository.pushCalls, 1);
      expect(clipboardRepository.items.first.content, 'https://example.com');
    });
  });

  group('stream en vivo (warm start)', () {
    test('sube archivos recibidos en caliente', () async {
      final dir = await Directory.systemTemp.createTemp('tether_share');
      final file = File('${dir.path}/doc.pdf');
      await file.writeAsBytes([1, 2, 3]);

      await controller.start();
      await controller.process([makeSharedMedia(path: file.path)]);

      expect(uploadService.uploadedPaths, contains(file.path));
      expect(filesReceivedCalls, 1);
      await dir.delete(recursive: true);
    });

    test('envía texto recibido en caliente al portapapeles', () async {
      await controller.start();
      service.emit([
        makeSharedMedia(path: 'texto en vivo', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(clipboardRepository.items.single.content, 'texto en vivo');
    });

    test('stop detiene la escucha', () async {
      await controller.start();
      controller.stop();
      service.emit([
        makeSharedMedia(path: 'tras parar', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(clipboardRepository.items, isEmpty);
    });
  });
}
