import 'package:dio/dio.dart';

import '../../../core/api/endpoints.dart';
import '../domain/device.dart';

class DevicesApi {
  DevicesApi(this._dio);

  final Dio _dio;

  Future<List<Device>> list() async {
    final res = await _dio.get<List<dynamic>>(Endpoints.devices);
    final items = res.data ?? const [];
    return items
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Device> create({
    required String name,
    required DevicePlatform platform,
  }) async {
    final res = await _dio.post(
      Endpoints.devices,
      data: {'name': name, 'platform': platform.wire},
    );
    return Device.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Device> rename(String id, String name) async {
    final res = await _dio.patch(
      Endpoints.deviceById(id),
      data: {'name': name},
    );
    return Device.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete(Endpoints.deviceById(id));
  }

  Future<void> heartbeat(String id) async {
    await _dio.post(Endpoints.deviceHeartbeat(id));
  }
}
