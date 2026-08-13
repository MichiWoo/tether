import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/realtime_service.dart';
import '../data/clipboard_api.dart';
import '../data/clipboard_repository.dart';
import '../domain/clipboard_item.dart';

final clipboardApiProvider = Provider<ClipboardApi>(
  (ref) => ClipboardApi(ref.watch(apiClientProvider)),
);

final clipboardRepositoryProvider = Provider<ClipboardRepository>(
  (ref) => ClipboardRepository(ref.watch(clipboardApiProvider)),
);

class ClipboardState {
  const ClipboardState({
    required this.items,
    this.isLoading = false,
    this.error,
  });

  final List<ClipboardItem> items;
  final bool isLoading;
  final String? error;

  ClipboardState copyWith({
    List<ClipboardItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => ClipboardState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final clipboardControllerProvider =
    StateNotifierProvider<ClipboardController, ClipboardState>(
      (ref) => ClipboardController(
        repository: ref.watch(clipboardRepositoryProvider),
        realtime: ref.watch(realtimeServiceProvider),
      )..init(),
    );

class ClipboardController extends StateNotifier<ClipboardState> {
  ClipboardController({required this.repository, required this.realtime})
    : super(const ClipboardState(items: [])) {
    _cancelUpdated = realtime.onEvent(
      RealtimeEvents.clipboardUpdated,
      _onClipboardUpdated,
    );
  }

  final ClipboardRepository repository;
  final RealtimeService realtime;
  late final void Function() _cancelUpdated;

  @override
  void dispose() {
    _cancelUpdated();
    super.dispose();
  }

  Future<void> init() => loadHistory();

  Future<void> loadHistory({int limit = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await repository.history(limit: limit);
      state = ClipboardState(items: items);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudo cargar el historial.',
      );
    }
  }

  /// Sube texto al portapapeles (dedupe en el servidor) e inserta el item
  /// resultante al inicio si es nuevo.
  Future<void> push({
    required String content,
    String? sourceDeviceId,
  }) async {
    try {
      final item = await repository.push(
        content: content,
        sourceDeviceId: sourceDeviceId,
      );
      final exists = state.items.any((i) => i.id == item.id);
      if (!exists) {
        state = state.copyWith(items: [item, ...state.items]);
      }
    } catch (_) {
      state = state.copyWith(error: 'No se pudo enviar el texto.');
    }
  }

  void _onClipboardUpdated(dynamic payload) {
    final raw = payload is Map ? payload : const <String, dynamic>{};
    final itemRaw = raw['item'];
    if (itemRaw is! Map) return;
    final item = ClipboardItem.fromJson(
      Map<String, dynamic>.from(itemRaw),
    );
    final exists = state.items.any((i) => i.id == item.id);
    if (!exists) {
      state = state.copyWith(items: [item, ...state.items]);
    }
  }
}
