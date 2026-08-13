import 'package:flutter_test/flutter_test.dart';
import 'package:tether_app/core/realtime/realtime_service.dart';
import 'package:tether_app/features/files/domain/share.dart';
import 'package:tether_app/features/files/providers/shares_provider.dart';

import '../../helpers/fake_devices.dart';
import '../../helpers/fake_files.dart';
import '../../helpers/fake_realtime_service.dart';

void main() {
  late FakeSharesRepository repository;
  late FakeRealtimeService realtime;
  late SharesController controller;

  setUp(() {
    repository = FakeSharesRepository();
    realtime = FakeRealtimeService();
    controller = SharesController(
      repository: repository,
      realtime: realtime,
      storage: MemoryDeviceStorage()..saveDeviceId('local'),
    );
  });

  tearDown(() => controller.dispose());

  Map<String, dynamic> shareJson(Share share, {ShareStatus? status}) => {
        'id': share.id,
        'status': status?.name.toUpperCase() ?? 'CREATED',
        'file': {
          'id': 'file-${share.id}',
          'name': 'doc.pdf',
          'size': 100,
          'mimeType': 'application/pdf',
          'status': 'UPLOADED',
          'uploadedAt': share.createdAt.toUtc().toIso8601String(),
          'createdAt': share.createdAt.toUtc().toIso8601String(),
        },
        'senderDeviceId': share.senderDeviceId,
        'targetDeviceId': share.targetDeviceId,
        'expiresAt': share.expiresAt.toUtc().toIso8601String(),
        'createdAt': share.createdAt.toUtc().toIso8601String(),
      };

  group('load', () {
    test('carga la lista de shares', () async {
      repository.shares.addAll([makeShare(id: 's1'), makeShare(id: 's2', senderDeviceId: 'local')]);
      await controller.load();
      expect(controller.state.shares.length, 2);
      expect(controller.state.error, isNull);
    });

    test('expone error si falla la carga', () async {
      repository.failLoad = true;
      await controller.load();
      expect(controller.state.shares, isEmpty);
      expect(controller.state.error, isNotNull);
    });
  });

  group('create', () {
    test('agrega el share al inicio de la lista', () async {
      await controller.create(fileId: 'f1');
      expect(controller.state.shares.length, 1);
      expect(controller.state.shares.first.status, ShareStatus.created);

      await controller.create(fileId: 'f2');
      expect(controller.state.shares.length, 2);
    });

    test('no duplica un share ya recibido en vivo', () async {
      await controller.create(fileId: 'f1');
      final id = controller.state.shares.single.id;

      realtime.emit(
        RealtimeEvents.shareCreated,
        {'share': shareJson(makeShare(id: id, senderDeviceId: 'local'))},
      );
      expect(controller.state.shares.length, 1);
    });
  });

  group('accept/downloaded/cancel', () {
    test('acepta y actualiza el estado', () async {
      repository.shares.add(makeShare(id: 's1'));
      await controller.load();

      await controller.accept('s1');
      expect(controller.state.shares.single.status, ShareStatus.accepted);
      expect(controller.state.shares.single.acceptedAt, isNotNull);
    });

    test('marca descargado', () async {
      repository.shares.add(makeShare(id: 's1', status: ShareStatus.accepted));
      await controller.load();

      await controller.markDownloaded('s1');
      expect(controller.state.shares.single.status, ShareStatus.downloaded);
      expect(controller.state.shares.single.downloadedAt, isNotNull);
    });

    test('cancela (expira)', () async {
      repository.shares.add(makeShare(id: 's1'));
      await controller.load();

      await controller.cancel('s1');
      expect(controller.state.shares.single.status, ShareStatus.expired);
      expect(repository.cancelCalls, 1);
    });
  });

  group('getDownloadUrl', () {
    test('delega en el repositorio', () async {
      expect(await controller.getDownloadUrl('s1'),
          'https://example.com/share.bin');
    });
  });

  group('eventos en vivo', () {
    test('share.created agrega un share recibido', () async {
      final share = makeShare(id: 's9', senderDeviceId: 'otro-device');
      realtime.emit(
        RealtimeEvents.shareCreated,
        {'share': shareJson(share)},
      );
      expect(controller.state.shares.single.id, 's9');
      expect(controller.state.shares.single.status, ShareStatus.created);
    });

    test('share.accepted actualiza el share existente', () async {
      repository.shares.add(makeShare(id: 's1', senderDeviceId: 'local'));
      await controller.load();

      realtime.emit(
        RealtimeEvents.shareAccepted,
        {'share': shareJson(makeShare(id: 's1'), status: ShareStatus.accepted)},
      );
      expect(controller.state.shares.single.status, ShareStatus.accepted);
    });

    test('share.downloaded actualiza el share existente', () async {
      repository.shares.add(makeShare(id: 's1', senderDeviceId: 'local'));
      await controller.load();

      realtime.emit(
        RealtimeEvents.shareDownloaded,
        {'share': shareJson(makeShare(id: 's1'), status: ShareStatus.downloaded)},
      );
      expect(controller.state.shares.single.status, ShareStatus.downloaded);
    });

    test('share.expired marca expirado por shareId', () async {
      repository.shares.add(makeShare(id: 's1', senderDeviceId: 'local'));
      await controller.load();

      realtime.emit(RealtimeEvents.shareExpired, {'shareId': 's1'});
      expect(controller.state.shares.single.status, ShareStatus.expired);
    });
  });
}