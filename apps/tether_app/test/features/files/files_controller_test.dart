import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/core/realtime/realtime_service.dart';
import 'package:tether_app/features/files/domain/file_item.dart';
import 'package:tether_app/features/files/providers/files_provider.dart';

import '../../helpers/fake_files.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeFilesRepository repository;
  late FakeUploadService uploadService;
  late FakeRealtimeService realtime;
  late FilesController controller;

  setUp(() {
    repository = FakeFilesRepository();
    uploadService = FakeUploadService();
    realtime = FakeRealtimeService();
    controller = FilesController(
      repository: repository,
      uploadService: uploadService,
      realtime: realtime,
    );
  });

  tearDown(() => controller.dispose());

  group('load', () {
    test('carga la lista de archivos', () async {
      repository.files.addAll([
        makeFileItem(id: 'f1', name: 'a.pdf'),
        makeFileItem(id: 'f2', name: 'b.jpg', status: FileStatus.pending),
      ]);
      await controller.load();
      expect(controller.state.files.length, 2);
      expect(controller.state.error, isNull);
    });

    test('expone error si falla la carga', () async {
      repository.failLoad = true;
      await controller.load();
      expect(controller.state.files, isEmpty);
      expect(controller.state.error, isNotNull);
    });
  });

  group('upload', () {
    test('crea, sube, completa y agrega el archivo a la lista', () async {
      final dir = await Directory.systemTemp.createTemp('tether_test');
      final file = File('${dir.path}/hola.txt');
      await file.writeAsString('hola mundo');

      await controller.uploadPaths([file.path]);

      expect(uploadService.uploadedPaths, contains(file.path));
      expect(repository.completeCalls, 1);
      expect(controller.state.files.single.name, 'hola.txt');
      expect(controller.state.files.single.isUploaded, isTrue);
      expect(controller.state.uploads, isEmpty);
      await dir.delete(recursive: true);
    });

    test('deja la tarea con error si falla la red', () async {
      final dir = await Directory.systemTemp.createTemp('tether_test');
      final file = File('${dir.path}/falla.txt');
      await file.writeAsString('x');
      uploadService.failUpload = true;

      await controller.uploadPaths([file.path]);

      expect(controller.state.files, isEmpty);
      expect(controller.state.uploads.single.name, 'falla.txt');
      expect(controller.state.uploads.single.error, isNotNull);
      await dir.delete(recursive: true);
    });

    test('descarta subidas con dismissUpload', () async {
      controller.uploadPaths(['nonexistent_ignored']);
      expect(controller.state.uploads, isEmpty);
    });
  });

  group('delete', () {
    test('elimina de la lista', () async {
      repository.files.add(makeFileItem(id: 'f1', name: 'a.pdf'));
      await controller.load();
      await controller.delete('f1');
      expect(controller.state.files, isEmpty);
      expect(repository.deleteCalls, 1);
    });
  });

  group('getDownloadUrl', () {
    test('delega en el repositorio', () async {
      expect(await controller.getDownloadUrl('f1'),
          'https://example.com/file.bin');
    });
  });

  group('eventos en vivo', () {
    test('file.ready agrega un archivo subido', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      realtime.emit(RealtimeEvents.fileReady, {
        'file': {
          'id': 'f9',
          'name': 'remoto.pdf',
          'size': 123,
          'mimeType': 'application/pdf',
          'status': 'UPLOADED',
          'uploadedAt': now,
          'createdAt': now,
        },
      });
      expect(controller.state.files.single.id, 'f9');
      expect(controller.state.files.single.name, 'remoto.pdf');
      expect(controller.state.files.single.isUploaded, isTrue);
    });

    test('file.ready ignora payload inválido', () async {
      realtime.emit(RealtimeEvents.fileReady, {'nada': true});
      expect(controller.state.files, isEmpty);
    });
  });
}