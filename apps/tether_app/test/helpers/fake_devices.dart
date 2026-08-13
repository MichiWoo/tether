import 'package:dio/dio.dart';
import 'package:tether_app/core/storage/device_storage.dart';
import 'package:tether_app/features/devices/data/devices_api.dart';
import 'package:tether_app/features/devices/data/devices_repository.dart';
import 'package:tether_app/features/devices/domain/device.dart';

/// DevicesRepository con comportamiento controlado para tests.
class FakeDevicesRepository extends DevicesRepository {
  FakeDevicesRepository() : super(FakeDevicesApi());

  final List<Device> devices = [];
  bool failLoad = false;
  bool failDelete = false;
  int registerCalls = 0;
  int renameCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<Device>> list() async {
    if (failLoad) throw StateError('boom');
    return List.of(devices);
  }

  @override
  Future<Device> register({required String name, required DevicePlatform platform}) async {
    registerCalls++;
    final device = Device(
      id: 'd$registerCalls',
      name: name,
      platform: platform,
      isOnline: false,
      createdAt: DateTime.now(),
    );
    devices.add(device);
    return device;
  }

  @override
  Future<Device> rename(String id, String name) async {
    renameCalls++;
    final index = devices.indexWhere((d) => d.id == id);
    final updated = devices[index].copyWith(name: name);
    devices[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    if (failDelete) throw StateError('boom');
    devices.removeWhere((d) => d.id == id);
  }
}

class FakeDevicesApi extends DevicesApi {
  FakeDevicesApi() : super(Dio());
}

/// DeviceStorage en memoria para tests.
class MemoryDeviceStorage extends DeviceStorage {
  String? _id;

  @override
  Future<String?> readDeviceId() async => _id;

  @override
  Future<void> saveDeviceId(String id) async {
    _id = id;
  }
}
