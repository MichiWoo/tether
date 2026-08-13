import 'package:dio/dio.dart';

import '../../../core/api/endpoints.dart';
import '../domain/clipboard_item.dart';

class ClipboardApi {
  ClipboardApi(this._dio);

  final Dio _dio;

  Future<ClipboardItem> push({
    required String content,
    String? sourceDeviceId,
  }) async {
    final res = await _dio.post(
      Endpoints.clipboard,
      data: {
        'content': content,
        if (sourceDeviceId != null) 'sourceDeviceId': sourceDeviceId,
      },
    );
    return ClipboardItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ClipboardItem>> history({int limit = 20}) async {
    final res = await _dio.get<List<dynamic>>(
      Endpoints.clipboardHistory,
      queryParameters: {'limit': limit},
    );
    final items = res.data ?? const [];
    return items
        .map((e) => ClipboardItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClipboardItem?> latest() async {
    final res = await _dio.get<Map<String, dynamic>?>(Endpoints.clipboardLatest);
    final data = res.data;
    if (data == null) return null;
    return ClipboardItem.fromJson(data);
  }
}
