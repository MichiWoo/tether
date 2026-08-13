import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../domain/clipboard_item.dart';
import '../providers/clipboard_provider.dart';
import '../../devices/providers/devices_provider.dart';

/// Pantalla de portapapeles: envía texto, muestra el historial y permite
/// copiarlo en este dispositivo.
class ClipboardScreen extends ConsumerStatefulWidget {
  const ClipboardScreen({super.key});

  @override
  ConsumerState<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends ConsumerState<ClipboardScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(clipboardControllerProvider.notifier).loadHistory());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    final deviceId =
        await ref.read(devicesControllerProvider.notifier).currentDeviceId();
    await ref.read(clipboardControllerProvider.notifier).push(
          content: content,
          sourceDeviceId: deviceId,
        );
    _controller.clear();
  }

  Future<void> _copy(ClipboardItem item) async {
    final ok = await ref.read(clipboardWriterProvider).writeText(item.content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Copiado en este dispositivo.'
                : 'El portapapeles no está disponible.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clipboardControllerProvider);

    // Avisa cuando un item llegó de otro dispositivo y se auto-copió.
    ref.listen<ClipboardState>(clipboardControllerProvider, (previous, next) {
      final item = next.autoCopiedItem;
      if (item != null && item.id != previous?.autoCopiedItem?.id) {
        final source = item.sourceDeviceName ?? 'otro dispositivo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copiado de $source.')),
        );
        ref.read(clipboardControllerProvider.notifier).clearAutoCopied();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: shadcn.TextField(
                  key: const Key('clipboard-input'),
                  controller: _controller,
                  hintText: 'Texto para enviar…',
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              shadcn.Button.primary(
                onPressed: _send,
                leading: const Icon(Icons.send),
                child: const Text('Enviar'),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ErrorBanner(message: state.error!),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: state.isLoading && state.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.items.isEmpty
                  ? const EmptyState(
                      icon: Icons.content_paste_go_outlined,
                      title: 'Sin historial',
                      subtitle:
                          'Envía texto desde cualquier dispositivo para verlo aquí.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref
                          .read(clipboardControllerProvider.notifier)
                          .loadHistory(),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return _ClipboardTile(
                              item: item, onCopy: () => _copy(item));
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _ClipboardTile extends StatelessWidget {
  const _ClipboardTile({required this.item, required this.onCopy});

  final ClipboardItem item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      title: Text(
        item.content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          item.sourceDeviceName ?? 'Desconocido',
          style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
      trailing: IconButton(
        tooltip: 'Copiar',
        icon: const Icon(Icons.copy),
        onPressed: onCopy,
      ),
      onTap: onCopy,
    );
  }
}
