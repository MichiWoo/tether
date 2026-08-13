import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_factory.dart';

/// Persistencia local del identificador del dispositivo actual (Keychain).
class DeviceStorage {
  DeviceStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? createSecureStorage();

  static const _kDeviceId = 'local_device_id';

  final FlutterSecureStorage _storage;

  Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);

  Future<void> saveDeviceId(String id) =>
      _storage.write(key: _kDeviceId, value: id);
}
