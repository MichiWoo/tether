import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_storage.dart';

/// Persistencia del `deviceId` del dispositivo actual.
final deviceStorageProvider = Provider<DeviceStorage>((ref) => DeviceStorage());
