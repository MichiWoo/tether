import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/device_storage_provider.dart';
import '../data/devices_api.dart';
import '../data/devices_repository.dart';
import '../domain/device.dart';

final devicesApiProvider = Provider<DevicesApi>(
  (ref) => DevicesApi(ref.watch(apiClientProvider)),
);

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(ref.watch(devicesApiProvider)),
);

/// Id del dispositivo actual (el equipo donde corre la app), si ya se registró.
final localDeviceIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(deviceStorageProvider).readDeviceId(),
);

class DevicesState {
  const DevicesState({
    required this.devices,
    this.error,
    this.isLoading = false,
  });

  final List<Device> devices;
  final String? error;
  final bool isLoading;

  DevicesState copyWith({
    List<Device>? devices,
    String? error,
    bool clearError = false,
    bool? isLoading,
  }) => DevicesState(
        devices: devices ?? this.devices,
        error: clearError ? null : error ?? this.error,
        isLoading: isLoading ?? this.isLoading,
      );
}

final devicesControllerProvider =
    StateNotifierProvider<DevicesController, DevicesState>(
      (ref) => DevicesController(
        repository: ref.watch(devicesRepositoryProvider),
        storage: ref.watch(deviceStorageProvider),
        realtime: ref.watch(realtimeServiceProvider),
      )..init(),
    );

class DevicesController extends StateNotifier<DevicesState> {
  DevicesController({
    required this.repository,
    required this.storage,
    required this.realtime,
  }) : super(const DevicesState(devices: [])) {
    _cancelOnline = realtime.onEvent(
      RealtimeEvents.deviceOnline,
      (payload) => _applyStatus(payload, online: true),
    );
    _cancelOffline = realtime.onEvent(
      RealtimeEvents.deviceOffline,
      (payload) => _applyStatus(payload, online: false),
    );
  }

  final DevicesRepository repository;
  final DeviceStorage storage;
  final RealtimeService realtime;
  late final void Function() _cancelOnline;
  late final void Function() _cancelOffline;

  @override
  void dispose() {
    _cancelOnline();
    _cancelOffline();
    super.dispose();
  }

  Future<void> init() => load();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final devices = await repository.list();
      state = DevicesState(devices: devices);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron cargar los dispositivos.',
      );
    }
  }

  /// Devuelve el id del dispositivo actual registrado, o `null` si aún no
  /// se registró. No cambia de estado; es consulta pura para flujos externos.
  Future<String?> currentDeviceId() => storage.readDeviceId();

  /// Registra el dispositivo actual si no existe aún y lo identifica en el
  /// WebSocket. Devuelve su id (para persistir como "este equipo").
  Future<String> ensureCurrentDevice({
    required String name,
    required DevicePlatform platform,
  }) async {
    final localId = await storage.readDeviceId();
    if (localId != null) {
      realtime.identify(localId);
      return localId;
    }
    final device = await repository.register(name: name, platform: platform);
    await storage.saveDeviceId(device.id);
    realtime.identify(device.id);
    state = state.copyWith(devices: [device, ...state.devices]);
    return device.id;
  }

  Future<void> register({
    required String name,
    required DevicePlatform platform,
  }) async {
    final device = await repository.register(name: name, platform: platform);
    state = state.copyWith(devices: [device, ...state.devices]);
  }

  Future<void> rename(String id, String name) async {
    final updated = await repository.rename(id, name);
    state = state.copyWith(
      devices: [
        for (final d in state.devices)
          if (d.id == id) updated else d,
      ],
    );
  }

  Future<void> delete(String id) async {
    await repository.delete(id);
    state = state.copyWith(
      devices: state.devices.where((d) => d.id != id).toList(),
    );
  }

  void _applyStatus(dynamic payload, {required bool online}) {
    final raw = payload is Map ? payload : const <String, dynamic>{};
    final id = raw['deviceId'];
    if (id is! String) return;
    state = state.copyWith(
      devices: [
        for (final d in state.devices)
          if (d.id == id)
            d.copyWith(
              isOnline: online,
              lastSeenAt: online ? DateTime.now() : d.lastSeenAt,
            )
          else
            d,
      ],
    );
  }
}

/// La plataforma actual según el dispositivo donde corre la app.
DevicePlatform currentPlatform() {
  if (kIsWeb) return DevicePlatform.web;
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return DevicePlatform.macos;
    case TargetPlatform.windows:
      return DevicePlatform.windows;
    case TargetPlatform.linux:
      return DevicePlatform.linux;
    case TargetPlatform.iOS:
      return DevicePlatform.ios;
    case TargetPlatform.android:
      return DevicePlatform.android;
    case TargetPlatform.fuchsia:
      return DevicePlatform.web;
  }
}
