import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/features/files/providers/downloads_provider.dart';

import '../../helpers/fake_files.dart';

void main() {
  late FakeUploadService uploadService;
  late DownloadsController controller;

  setUp(() {
    uploadService = FakeUploadService();
    controller = DownloadsController(uploadService);
  });

  tearDown(() => controller.dispose());

  group('start', () {
    test('agrega la tarea, reporta progreso y la quita al terminar', () async {
      final ok = await controller.start(
        name: 'archivo.pdf',
        url: 'https://example.com/file.bin',
        savePath: '/tmp/archivo.pdf',
      );

      expect(ok, isTrue);
      expect(uploadService.downloadedUrls, contains('https://example.com/file.bin'));
      expect(controller.state.downloads, isEmpty);
    });

    test('marca error si falla la descarga y devuelve false', () async {
      uploadService.failDownload = true;

      final ok = await controller.start(
        name: 'archivo.pdf',
        url: 'https://example.com/file.bin',
        savePath: '/tmp/archivo.pdf',
      );

      expect(ok, isFalse);
      expect(controller.state.downloads.single.name, 'archivo.pdf');
      expect(controller.state.downloads.single.error, isNotNull);
    });

    test('corre varias descargas en paralelo', () async {
      final gate = Completer<void>();
      uploadService.downloadGate = gate;

      final f1 = controller.start(
        name: 'a.pdf',
        url: 'https://example.com/a.bin',
        savePath: '/tmp/a.pdf',
      );
      final f2 = controller.start(
        name: 'b.pdf',
        url: 'https://example.com/b.bin',
        savePath: '/tmp/b.pdf',
      );

      expect(controller.state.downloads.length, 2);

      gate.complete();
      await Future.wait([f1, f2]);

      expect(controller.state.downloads, isEmpty);
    });
  });

  group('cancel', () {
    test('quita la tarea y resuelve false', () async {
      final gate = Completer<void>();
      uploadService.downloadGate = gate;

      final future = controller.start(
        name: 'grande.bin',
        url: 'https://example.com/big.bin',
        savePath: '/tmp/grande.bin',
      );
      final id = controller.state.downloads.single.id;

      controller.cancel(id);
      expect(controller.state.downloads, isEmpty);

      gate.complete();
      expect(await future, isFalse);
    });
  });

  group('dismiss', () {
    test('quita un tile con error', () async {
      uploadService.failDownload = true;

      await controller.start(
        name: 'falla.pdf',
        url: 'https://example.com/f.bin',
        savePath: '/tmp/falla.pdf',
      );
      final id = controller.state.downloads.single.id;

      controller.dismiss(id);

      expect(controller.state.downloads, isEmpty);
    });
  });
}
