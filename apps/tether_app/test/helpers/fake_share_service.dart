import 'package:tether_app/features/files/data/share_service.dart';

/// ShareService en memoria para tests (no invoca el share sheet real).
class FakeShareService extends ShareService {
  final List<String> sharedPaths = [];
  final List<String> sharedTexts = [];
  bool failShare = false;

  @override
  Future<void> shareFile({required String path, String? text}) async {
    if (failShare) throw StateError('boom');
    sharedPaths.add(path);
  }

  @override
  Future<void> shareText(String text) async {
    if (failShare) throw StateError('boom');
    sharedTexts.add(text);
  }
}
