import 'package:dio/dio.dart';
import 'package:tether_app/features/clipboard/data/clipboard_api.dart';
import 'package:tether_app/features/clipboard/data/clipboard_repository.dart';
import 'package:tether_app/features/clipboard/domain/clipboard_item.dart';

/// ClipboardRepository con comportamiento controlado para tests.
class FakeClipboardRepository extends ClipboardRepository {
  FakeClipboardRepository() : super(FakeClipboardApi());

  final List<ClipboardItem> items = [];
  bool failHistory = false;
  bool failPush = false;
  int pushCalls = 0;

  @override
  Future<List<ClipboardItem>> history({int limit = 20}) async {
    if (failHistory) throw StateError('boom');
    return List.of(items);
  }

  @override
  Future<ClipboardItem> push({required String content, String? sourceDeviceId}) async {
    pushCalls++;
    if (failPush) throw StateError('boom');
    final item = ClipboardItem(
      id: 'c$pushCalls',
      content: content,
      sourceDeviceId: sourceDeviceId,
      createdAt: DateTime.now(),
    );
    items.insert(0, item);
    return item;
  }
}

class FakeClipboardApi extends ClipboardApi {
  FakeClipboardApi() : super(Dio());
}
