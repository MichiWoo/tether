import 'package:dio/dio.dart';

import '../../../core/api/endpoints.dart';
import '../domain/share.dart';

class SharesApi {
  SharesApi(this._dio);

  final Dio _dio;

  Future<Share> create({
    required String fileId,
    String? targetDeviceId,
    String? senderDeviceId,
  }) async {
    final res = await _dio.post(
      Endpoints.shares,
      data: {
        'fileId': fileId,
        if (targetDeviceId != null) 'targetDeviceId': targetDeviceId,
        if (senderDeviceId != null) 'senderDeviceId': senderDeviceId,
      },
    );
    return Share.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Share>> list({String? status}) async {
    final res = await _dio.get<List<dynamic>>(
      Endpoints.shares,
      queryParameters: {if (status != null) 'status': status},
    );
    final items = res.data ?? const [];
    return items
        .map((e) => Share.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detalle del share con URL firmada de descarga (null si expiró).
  Future<String?> getDownloadUrl(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(Endpoints.shareById(id));
    final data = res.data!;
    return data['downloadUrl'] as String?;
  }

  Future<Share> accept(String id) async {
    final res = await _dio.post(Endpoints.shareAccept(id));
    return Share.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Share> downloaded(String id) async {
    final res = await _dio.post(Endpoints.shareDownloaded(id));
    return Share.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Share> cancel(String id) async {
    final res = await _dio.post(Endpoints.shareCancel(id));
    return Share.fromJson(res.data as Map<String, dynamic>);
  }
}
