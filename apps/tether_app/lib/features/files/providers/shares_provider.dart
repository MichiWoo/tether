import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/device_storage_provider.dart';
import '../data/shares_api.dart';
import '../data/shares_repository.dart';
import '../domain/share.dart';

final sharesApiProvider = Provider<SharesApi>(
  (ref) => SharesApi(ref.watch(apiClientProvider)),
);

final sharesRepositoryProvider = Provider<SharesRepository>(
  (ref) => SharesRepository(ref.watch(sharesApiProvider)),
);

class SharesState {
  const SharesState({
    required this.shares,
    this.isLoading = false,
    this.error,
  });

  final List<Share> shares;
  final bool isLoading;
  final String? error;

  SharesState copyWith({
    List<Share>? shares,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => SharesState(
        shares: shares ?? this.shares,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final sharesControllerProvider =
    StateNotifierProvider<SharesController, SharesState>(
      (ref) => SharesController(
        repository: ref.watch(sharesRepositoryProvider),
        realtime: ref.watch(realtimeServiceProvider),
        storage: ref.watch(deviceStorageProvider),
      )..init(),
    );

class SharesController extends StateNotifier<SharesState> {
  SharesController({
    required this.repository,
    required this.realtime,
    required this.storage,
  }) : super(const SharesState(shares: [])) {
    _cancelCreated = realtime.onEvent(
      RealtimeEvents.shareCreated,
      (p) => _onShareEvent(p, 'created'),
    );
    _cancelAccepted = realtime.onEvent(
      RealtimeEvents.shareAccepted,
      (p) => _onShareEvent(p, 'accepted'),
    );
    _cancelDownloaded = realtime.onEvent(
      RealtimeEvents.shareDownloaded,
      (p) => _onShareEvent(p, 'downloaded'),
    );
    _cancelExpired = realtime.onEvent(
      RealtimeEvents.shareExpired,
      _onShareExpired,
    );
  }

  final SharesRepository repository;
  final RealtimeService realtime;
  final DeviceStorage storage;
  late final void Function() _cancelCreated;
  late final void Function() _cancelAccepted;
  late final void Function() _cancelDownloaded;
  late final void Function() _cancelExpired;

  @override
  void dispose() {
    _cancelCreated();
    _cancelAccepted();
    _cancelDownloaded();
    _cancelExpired();
    super.dispose();
  }

  Future<void> init() => load();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final shares = await repository.list();
      state = SharesState(shares: shares);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron cargar los shares.',
      );
    }
  }

  Future<void> create({required String fileId, String? targetDeviceId}) async {
    final senderDeviceId = await storage.readDeviceId();
    final share = await repository.create(
      fileId: fileId,
      targetDeviceId: targetDeviceId,
      senderDeviceId: senderDeviceId,
    );
    final exists = state.shares.any((s) => s.id == share.id);
    state = state.copyWith(
      shares: exists ? state.shares : [share, ...state.shares],
    );
  }

  Future<Share> accept(String id) async {
    final share = await repository.accept(id);
    _replace(share);
    return share;
  }

  Future<Share> markDownloaded(String id) async {
    final share = await repository.downloaded(id);
    _replace(share);
    return share;
  }

  Future<Share> cancel(String id) async {
    final share = await repository.cancel(id);
    _replace(share);
    return share;
  }

  /// Devuelve la URL firmada de descarga del share (null si expiró).
  Future<String?> getDownloadUrl(String id) => repository.getDownloadUrl(id);

  void _onShareEvent(dynamic payload, String kind) {
    final raw = payload is Map ? payload : const <String, dynamic>{};
    final shareRaw = raw['share'];
    if (shareRaw is! Map) return;
    final share = Share.fromJson(Map<String, dynamic>.from(shareRaw));
    _upsert(share);
  }

  void _onShareExpired(dynamic payload) {
    final raw = payload is Map ? payload : const <String, dynamic>{};
    final id = raw['shareId'];
    if (id is! String) return;
    state = state.copyWith(
      shares: [
        for (final s in state.shares)
          if (s.id == id) s.copyWith(status: ShareStatus.expired) else s,
      ],
    );
  }

  void _upsert(Share share) {
    final exists = state.shares.any((s) => s.id == share.id);
    state = state.copyWith(
      shares: exists
          ? [
              for (final s in state.shares)
                if (s.id == share.id) share else s,
            ]
          : [share, ...state.shares],
    );
  }

  void _replace(Share share) {
    state = state.copyWith(
      shares: [
        for (final s in state.shares)
          if (s.id == share.id) share else s,
      ],
    );
  }
}
