import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:tether_app/core/sharing/receive_sharing_service.dart';

/// ReceiveSharingService con streams/valores controlados para tests.
class FakeReceiveSharingService extends ReceiveSharingService {
  List<SharedMediaFile> initialMedia = [];
  final StreamController<List<SharedMediaFile>> mediaController =
      StreamController<List<SharedMediaFile>>.broadcast();
  int resetCalls = 0;

  @override
  Stream<List<SharedMediaFile>> get mediaStream => mediaController.stream;

  @override
  Future<List<SharedMediaFile>> getInitialMedia() async =>
      List.of(initialMedia);

  @override
  Future<void> reset() async {
    resetCalls++;
    initialMedia = [];
  }

  void emit(List<SharedMediaFile> media) => mediaController.add(media);
}

SharedMediaFile makeSharedMedia({
  required String path,
  SharedMediaType type = SharedMediaType.file,
}) =>
    SharedMediaFile(path: path, type: type);
