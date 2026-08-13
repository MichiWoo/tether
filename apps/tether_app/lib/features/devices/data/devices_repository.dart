import '../domain/device.dart';
import 'devices_api.dart';

class DevicesRepository {
  DevicesRepository(this._api);

  final DevicesApi _api;

  Future<List<Device>> list() => _api.list();

  Future<Device> register({required String name, required DevicePlatform platform}) =>
      _api.create(name: name, platform: platform);

  Future<Device> rename(String id, String name) => _api.rename(id, name);

  Future<void> delete(String id) => _api.delete(id);

  Future<void> heartbeat(String id) => _api.heartbeat(id);
}
