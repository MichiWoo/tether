import '../domain/clipboard_item.dart';
import 'clipboard_api.dart';

class ClipboardRepository {
  ClipboardRepository(this._api);

  final ClipboardApi _api;

  Future<ClipboardItem> push({required String content, String? sourceDeviceId}) =>
      _api.push(content: content, sourceDeviceId: sourceDeviceId);

  Future<List<ClipboardItem>> history({int limit = 20}) =>
      _api.history(limit: limit);

  Future<ClipboardItem?> latest() => _api.latest();
}
